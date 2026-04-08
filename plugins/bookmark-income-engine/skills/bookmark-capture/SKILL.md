---
name: bookmark-capture
description: Captures X (Twitter) bookmarks via browser automation and outputs structured JSON. Capture-only — no scoring or task generation. Used internally by the bookmark-income-engine pipeline.
license: MIT
compatibility: Requires Claude in Chrome extension with an active Chrome session logged into X (Twitter). No Twitter API key needed.
metadata:
  author: WillyV347
  version: 2.0.0
  category: data-capture
  tags: [twitter, bookmarks, browser-automation, data-extraction]
---

# Bookmark Capture

Capture X (Twitter) bookmarks via browser automation and return structured JSON. This skill is the **read-only data source** for the bookmark-income-engine pipeline. It does NOT score, filter, or generate tasks — that work belongs to the downstream agents.

## Prerequisites

CRITICAL: Before starting, verify:
- Claude in Chrome extension is connected (check with `tabs_context_mcp`)
- User is logged into X in their Chrome browser
- If either fails, STOP and tell the user what to fix

## Input

The skill receives an optional `count` parameter (default: 30) indicating the target number of bookmarks to capture.

## Instructions

### Step 1: Open Bookmarks Page

1. Get browser context with `tabs_context_mcp` (set `createIfEmpty: true`)
2. Create a new tab via `tabs_create_mcp`, then navigate to `https://x.com/i/bookmarks`
3. Wait 3 seconds for page load, then take a screenshot to verify
4. If a login wall appears, STOP and tell the user: "Please log into X in Chrome, then re-run the command"

### Step 2: Capture Raw Content

1. Extract content using `get_page_text` — capture post text, author handles, dates, engagement metrics
2. Scroll down using `computer` with `scroll` action (direction: "down", scroll_amount: 5)
3. After each scroll, wait 2 seconds, then call `get_page_text` again to capture newly loaded bookmarks
4. Repeat scroll + capture until you have reached the target count or no new content loads after 2 consecutive scrolls
5. If `get_page_text` returns minimal content, fall back to `read_page` for DOM-based extraction

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
  "has_media": true/false,
  "has_links": true/false,
  "embedded_links": ["https://..."],
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

### Step 4: Deduplicate Against Previous Runs

Check if `/Users/willvowell/twitterBookmarks/output/.last-run` exists. If it does, read it and remove any bookmarks whose URLs appear in the previously processed list.

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

Report: "Captured X bookmarks (Y new after dedup)" where X is total captured and Y is after dedup filtering.

## Troubleshooting

**Login wall / "Sign in to X" screen**
→ User must log into X in Chrome manually, then re-run.

**`tabs_context_mcp` fails**
→ Claude in Chrome extension not installed or not connected.

**Bookmarks page appears empty**
→ User has no bookmarks. Tell them to verify at x.com/i/bookmarks.

**`get_page_text` returns minimal content**
→ X lazy-loads content. Wait 3 seconds after navigation, take screenshot to verify, then retry. Use `read_page` as fallback.

**Infinite scroll captures duplicates**
→ The dedup hash (`id` field) handles this. Duplicates within a single run are removed before output.
