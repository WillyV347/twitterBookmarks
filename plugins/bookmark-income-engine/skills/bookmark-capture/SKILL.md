---
name: bookmark-capture
description: Captures X (Twitter) bookmarks via browser automation and outputs structured JSON. Capture-only — no scoring or task generation. Used internally by the bookmark-income-engine pipeline.
license: MIT
compatibility: Requires Claude in Chrome extension with an active Chrome session logged into X (Twitter). No Twitter API key needed.
metadata:
  author: WillyV347
  version: 2.1.0
  category: data-capture
  tags: [twitter, bookmarks, browser-automation, data-extraction]
---

# Bookmark Capture

Capture X (Twitter) bookmarks via browser automation and return structured JSON. This skill is the **read-only data source** for the bookmark-income-engine pipeline. It does NOT score, filter, or generate tasks — that work belongs to the downstream agents.

## Prerequisites

CRITICAL: Before starting, verify:
- Claude in Chrome extension is connected (check with the Chrome tabs context tool)
- User is logged into X in their Chrome browser
- If either fails, STOP and tell the user what to fix

## Input

The skill receives an optional `count` parameter (default: 30) indicating the target number of bookmarks to capture.

## Instructions

### Step 1: Open Bookmarks Page

1. Get browser context with the Chrome tabs context tool (set `createIfEmpty: true`)
2. Create a new tab, then navigate to `https://x.com/i/bookmarks`
3. Wait 3 seconds for page load, then take a screenshot to verify
4. If a login wall appears, STOP and tell the user: "Please log into X in Chrome, then re-run the command"

### Step 2: Capture Raw Content

1. Extract content using the Chrome get-page-text tool — capture post text, author handles, dates, engagement metrics
2. Scroll down using the Chrome computer tool with scroll action (direction: "down", scroll_amount: 5)
3. After each scroll, wait 2 seconds, then capture text again for newly loaded bookmarks
4. Repeat scroll + capture until you have reached the target count or no new content loads after 2 consecutive scrolls
5. If get-page-text returns minimal content, fall back to read-page for DOM-based extraction

### Step 2.5: Thread + Link Enrichment

After parsing the visible bookmark list, run a single enrichment pass per bookmark. **Skip this pass entirely if total captured bookmarks > 50** — preserves speed on big runs. Note the skip in the final report.

**Thread detection.** A bookmark is a likely thread if any of these are true in the visible tweet text or DOM:
- Trailing thread markers: `🧵`, `(thread)`, `a thread:`, `see thread`, `more below`, `read on`, `keep reading`
- Numbered openers: `1/`, `1)`, `1 of `, `1.` at the start of a line
- A visible `Show this thread` element on the bookmarks page card

For each likely-thread bookmark:
1. Navigate to the bookmark `url` using the Chrome navigate tool
2. Wait 2 seconds, then capture text via get-page-text
3. Extract continuation replies **by the same author only**, in order. Stop at the first reply from a different author OR after 20 replies.
4. Concatenate continuation text into `thread_text` (cap at 4000 chars). Set `is_thread: true` and `thread_length` to the number of own-author replies captured.

If thread detection fires but no continuation is found (e.g., the indicators were a false positive), set `is_thread: false` and continue.

**Link preview fetch.** For every URL in `embedded_links`, fetch a lightweight preview using WebFetch with a prompt like `"Return the page title and the first 1000 characters of the main body content."`. Store the result in `link_previews`. Cap at 3 links per bookmark to keep the pass bounded. Skip URLs that point back to x.com / twitter.com (those are quote-tweets — handle in a later iteration).

If a fetch fails (404, blocked, timeout), record `{url, title: null, summary: "fetch_failed: <reason>"}` and continue — never abort the run on a single bad link.

After enrichment, return to the bookmarks tab so any subsequent scroll/capture passes work against the right context.

### Step 3: Parse Into Structured JSON

From the raw captured text, extract an array of bookmark objects. For each bookmark:

```json
{
  "id": "<hash of author+first50chars for dedup>",
  "author": "@handle",
  "display_name": "Display Name",
  "text": "Full post content (first 500 chars if longer)",
  "url": "https://x.com/{handle}/status/{id}",
  "date": "ISO date if visible, otherwise 'recent'",
  "has_media": true,
  "has_links": true,
  "embedded_links": ["https://..."],
  "is_thread": true,
  "thread_length": 0,
  "thread_text": "Concatenated own-author continuation replies, up to 4000 chars. Empty string if not a thread.",
  "link_previews": [
    {
      "url": "https://...",
      "title": "Page title or null",
      "summary": "First ~1000 chars of body, or 'fetch_failed: <reason>'"
    }
  ],
  "enrichment_skipped": false,
  "engagement": {
    "likes": 0,
    "retweets": 0,
    "replies": 0,
    "views": 0
  }
}
```

Rules:
- Construct URLs as `https://x.com/{handle}/status/{id}` when possible. If the status ID is not extractable, set url to `"not_captured"`.
- Extract any embedded URLs from the tweet text (links to tools, articles, products).
- Capture engagement metrics if visible; use 0 for any not displayed.
- Generate `id` as a simple hash of `author + first 50 chars of text` for deduplication.
- `is_thread`, `thread_length`, `thread_text`, and `link_previews` are populated by Step 2.5 (enrichment). If the enrichment pass was skipped due to the >50 bookmark cap, set `enrichment_skipped: true` and leave the thread/link fields at their defaults (`false`, `0`, `""`, `[]`).

### Step 4: Deduplicate Against Previous Runs

Look for the dedup tracker file. Check these locations in order:
1. `../../output/.last-run` (relative to this skill file)
2. The `output_dir` specified in `../../config.yaml` if it exists

If the tracker exists, read it and remove any bookmarks whose URLs appear in the previously processed list.

### Step 5: Output

Return the JSON array as the skill output. Do NOT write it to a file — the orchestrator agent will consume it directly.

Format the output clearly between markers so the orchestrator can parse it:

```
===BOOKMARKS_START===
[
  { ... },
  { ... }
]
===BOOKMARKS_END===
```

Report: "Captured X bookmarks (Y new after dedup, Z enriched with thread/link context)" where X is total captured, Y is after dedup filtering, and Z is the number of bookmarks the enrichment pass ran on (0 if skipped).

## Troubleshooting

**Login wall / "Sign in to X" screen**
-> User must log into X in Chrome manually, then re-run.

**Chrome tabs context fails**
-> Claude in Chrome extension not installed or not connected.

**Bookmarks page appears empty**
-> User has no bookmarks. Tell them to verify at x.com/i/bookmarks.

**Page text returns minimal content**
-> X lazy-loads content. Wait 3 seconds after navigation, take screenshot to verify, then retry. Use read-page as fallback.

**Infinite scroll captures duplicates**
-> The dedup hash (`id` field) handles this. Duplicates within a single run are removed before output.

**Thread permalink fails to load during enrichment**
-> Skip enrichment for that bookmark, set `is_thread: false`, leave `thread_text: ""`. Do NOT abort the whole run.

**WebFetch returns blocked/403 on an embedded link**
-> Record `summary: "fetch_failed: blocked"` in `link_previews` and continue. The opportunity-analyst can retry later if the lead looks promising.
