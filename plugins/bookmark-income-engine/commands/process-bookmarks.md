---
name: process-bookmarks
description: "Process X (Twitter) bookmarks through the Bookmark Income Engine — captures bookmarks via browser automation, classifies them, runs deep research on opportunities, maps skills to existing projects, and generates implementation plans. Outputs to Notion and markdown. Usage: /process-bookmarks [count]"
argument-hint: "[count]"
allowed-tools: ["Skill", "Agent", "Read", "Write", "Bash", "Glob", "Grep", "WebSearch", "WebFetch"]
model: opus
---

# Process Bookmarks Command

You are the entry point for the **Bookmark Income Engine**. When the user runs `/process-bookmarks`, you orchestrate the full pipeline: capture -> classify -> research -> plan -> output.

## First: Load Configuration

Resolve `config.yaml` deterministically by checking candidate locations **in priority order** and using the first one that exists. Do **not** assume any single hardcoded path — the plugin's own install directory is often mounted read-only (e.g. in Cowork / plugin-mount contexts), so a config saved there cannot persist and must never be treated as the canonical location.

Check these candidates, in order:

1. **`$BOOKMARK_ENGINE_CONFIG`** — if this environment variable is set, use the file it points to. This is the explicit override and always wins.
2. **`~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml`** — the documented stable path in the user's own workspace. This is the recommended home for the real config because it lives outside the plugin install directory and persists across sessions.
3. **`../../config.yaml`** (relative to this command file, i.e. the plugin bundle root) — **last-resort fallback only.** A config found or written here **will not persist between sessions** in plugin-mount contexts. If this is the only match, load it but warn the user to move it to the stable path above.

Resolve the path with a single deterministic check, for example:

```bash
CANDIDATES=(
  "${BOOKMARK_ENGINE_CONFIG:-}"
  "$HOME/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml"
  "$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/config.yaml"   # plugin bundle (won't persist)
)
CONFIG_PATH=""
for c in "${CANDIDATES[@]}"; do
  [ -n "$c" ] && [ -f "$c" ] && { CONFIG_PATH="$c"; break; }
done
```

(When resolving relative to this command file rather than a script, the plugin-root candidate is `<this-command-dir>/../../config.yaml`.)

If a config is found, note which candidate matched. If it matched **only** the plugin bundle path (#3), tell the user:
> "Loaded config.yaml from the plugin bundle path, which will NOT persist between sessions. Copy it to `~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml` (or set `$BOOKMARK_ENGINE_CONFIG`) so future sessions find it."

If **none** of the candidates exist, do **not** invent or reconstruct a config from the Notion schema, the `config.example.yaml` placeholders, or any other source — a fabricated config (e.g. the placeholder `my-saas-app` / `my-automation-bot` projects) is worse than no config and must never be used to run the pipeline.

Instead, **bootstrap a persistent config** so this stops recurring every session. Copy `config.example.yaml` from the plugin bundle to the stable path (candidate #2) — which lives outside the read-only plugin mount and therefore persists — creating the directory if needed:

```bash
STABLE_DIR="$HOME/Documents/Claude/Projects/AI Projects/bookmark-income-engine"
STABLE_CONFIG="$STABLE_DIR/config.yaml"
# EXAMPLE = config.example.yaml in the plugin bundle root (../.. from this skill/command file)
mkdir -p "$STABLE_DIR"
cp "$EXAMPLE" "$STABLE_CONFIG"
```

Then **stop** and tell the user exactly what happened — which paths were checked and what you created:
> "No config.yaml found. Checked, in order:
> 1. `$BOOKMARK_ENGINE_CONFIG` (not set)
> 2. `~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml` (missing)
> 3. `<plugin-root>/config.yaml` (missing — and read-only, would not persist)
>
> I copied the template to the stable path (#2):
> `~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml`
> It still has placeholder projects (`my-saas-app`, `my-automation-bot`). Edit it with your real mission, project portfolio, and skills, then re-run `/process-bookmarks`. I will not run the pipeline against the placeholders, and I will not guess your values."

If the stable directory cannot be created or written (e.g. sandbox restrictions), fall back to reporting the three checked paths and asking the user to create `config.yaml` at the stable path (or point `$BOOKMARK_ENGINE_CONFIG` at one) themselves.

Stop execution if no real (non-placeholder) config is available. If the resolved config still contains the example placeholders (`my-saas-app` / `my-automation-bot`), treat it as not yet configured: stop and ask the user to fill in their real values rather than processing bookmarks against fake projects.

Extract from config:
- `default_count` — fallback bookmark count
- `output_dir` — where to write output
- `projects` — for Notion database synergy field options

## Parse Arguments

- `$ARGUMENTS` may contain a number (target bookmark count). Default: value from config, or 30.
- Extract the count: `const count = parseInt($ARGUMENTS) || config.default_count || 30`

## Execution Pipeline

### 1. Ensure Notion Database Exists

Search Notion for a database called "Bookmark Income Pipeline" using whatever Notion MCP tools are available in your session (search for tools containing "notion" in their name).

If Notion tools are NOT available, skip this step — output will be markdown only. Inform the user.

If Notion is available but the database is NOT found, create it:

```
Use the Notion create-database tool with:
  title: "Bookmark Income Pipeline"
  schema: CREATE TABLE (
    "Name" TITLE,
    "Category" SELECT('Opportunity':green, 'Skill':blue, 'Hybrid':purple, 'Low Priority':gray),
    "Status" SELECT('New':default, 'Researched':yellow, 'Planned':orange, 'In Progress':green, 'Validated':green, 'Abandoned':red),
    "Source Author" RICH_TEXT,
    "Source URL" URL,
    "Tweet Summary" RICH_TEXT,
    "Revenue Estimate" RICH_TEXT,
    "Plausibility" NUMBER,
    "ROI Score" NUMBER,
    "Time to Revenue" RICH_TEXT,
    "Effort Hrs/Week" NUMBER,
    "Startup Cost" RICH_TEXT,
    "Synergy Projects" MULTI_SELECT({dynamically built from config projects}),
    "First Step" RICH_TEXT,
    "Has Plan" CHECKBOX,
    "Processed Date" DATE,
    "Go/No-Go" SELECT('GO':green, 'CONDITIONAL':yellow, 'NO-GO':red, 'PENDING':gray)
  )
```

Build the `Synergy Projects` MULTI_SELECT options dynamically from the project names in config.yaml.

After creation, create the 4 views:

1. **Pipeline Board**: board view, grouped by "Status"
2. **Top Opportunities**: table view, filtered to Category = "Opportunity", sorted by "ROI Score" descending
3. **Skill Map**: table view, filtered to Category = "Skill", grouped by "Synergy Projects"
4. **This Week's Actions**: list view, filtered to Status in ("New", "Researched"), sorted by "ROI Score" descending

Save the database ID and data source ID for later use.

### 2. Capture Bookmarks

Execute the bookmark-capture skill. This uses browser automation to:
- Open x.com/i/bookmarks in Chrome
- Scroll and capture bookmark content
- Parse into structured JSON
- Deduplicate against previous runs

The skill returns a JSON array between `===BOOKMARKS_START===` and `===BOOKMARKS_END===` markers.

If the skill reports 0 bookmarks, tell the user and stop.

### 3. Run the Orchestrator

Launch the `bookmark-orchestrator` agent with:
- The full bookmark JSON array
- The Notion database ID and data source ID (if available)
- Today's date
- The output path from config
- The full config context (mission, projects, skills) so it can pass to sub-agents

The orchestrator handles:
- Classification (OPPORTUNITY / SKILL / HYBRID / LOW)
- Parallel dispatch to specialist agents (opportunity-analyst, skill-compiler)
- Implementation planning for GO opportunities
- ROI ranking
- Notion output (creating pages in the database)
- Markdown summary output

### 4. Update Dedup Tracker

After the orchestrator completes, append the processed bookmark URLs to the dedup tracker:

```bash
OUTPUT_DIR="{output_dir from config}"
echo "---" >> "$OUTPUT_DIR/.last-run"
echo "run_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$OUTPUT_DIR/.last-run"
echo "urls:" >> "$OUTPUT_DIR/.last-run"
# Append each processed URL
```

### 5. Final Summary

Print a concise summary to the user:

```
## Bookmark Income Engine — Complete

**Processed**: X bookmarks
**Opportunities found**: X (Y with GO recommendation)
**Skills extracted**: X mapped to Z projects  
**Implementation plans**: X generated
**Estimated monthly revenue potential**: $X (conservative, GO opportunities only)

**Top 3 opportunities**:
1. {name} — ROI: {score} — First step: {step}
2. {name} — ROI: {score} — First step: {step}
3. {name} — ROI: {score} — First step: {step}

Full results: Notion -> "Bookmark Income Pipeline"
Markdown archive: {output_dir}/run-{date}.md
```

## Error Handling

- **Chrome not connected**: Tell user to install/connect Claude in Chrome extension
- **Not logged into X**: Tell user to log into X in Chrome first
- **Notion unavailable**: Skip Notion output, write everything to markdown, inform user
- **Config not found**: List every candidate path that was checked (see "Load Configuration"), then tell the user to copy `config.example.yaml` to the stable workspace path (outside the plugin install dir) or set `$BOOKMARK_ENGINE_CONFIG`. Never reconstruct config from the Notion schema.
- **Agent failures**: Log the error, continue with remaining bookmarks. Never lose data.
- **Empty bookmarks**: Report and suggest bookmarking more mission-aligned content

## Important

- This command should take 5-15 minutes depending on bookmark count
- All specialist agents run in parallel where possible to minimize wait time
- Every bookmark gets processed — nothing is silently dropped
- The mandate is income maximization — bias toward action over analysis
