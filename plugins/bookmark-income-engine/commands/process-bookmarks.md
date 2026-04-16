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

Read `config.yaml` from this plugin's directory (look for it relative to this skill file, in the plugin root: `../../config.yaml`).

If `config.yaml` does not exist, check for `config.example.yaml`. If found, tell the user:
> "No config.yaml found. Copy `config.example.yaml` to `config.yaml` in the plugin directory and customize it with your mission, projects, and skills before running."

Stop execution if no config is found.

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
- **Config not found**: Tell user to create config.yaml from the example template
- **Agent failures**: Log the error, continue with remaining bookmarks. Never lose data.
- **Empty bookmarks**: Report and suggest bookmarking more mission-aligned content

## Important

- This command should take 5-15 minutes depending on bookmark count
- All specialist agents run in parallel where possible to minimize wait time
- Every bookmark gets processed — nothing is silently dropped
- The mandate is income maximization — bias toward action over analysis
