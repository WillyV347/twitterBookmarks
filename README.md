# Bookmark Income Engine

A **Claude Code plugin** (Cowork-compatible) that transforms your X (Twitter) bookmarks into scored revenue opportunities, skill upgrades, and 30-day implementation plans using a multi-agent pipeline.

## What It Does

Run `/process-bookmarks` and the engine will:

1. **Capture** bookmarks from X via browser automation (no API key needed)
2. **Classify** each bookmark as Opportunity, Skill, Hybrid, or Low Priority
3. **Research** opportunities with web search, validate revenue claims, and score plausibility
4. **Map skills** from bookmarks to your existing projects with concrete action items
5. **Generate 30-day plans** for GO-rated opportunities with cost breakdowns and revenue projections
6. **Output** everything to a Notion database and local markdown

## Architecture

```
/process-bookmarks [count]
        |
   bookmark-capture (skill)        ← browser automation, dedup
        |
   bookmark-orchestrator (agent)   ← classify, dispatch, merge, rank
        |
   ┌────┴────┐
   |         |
opportunity  skill-compiler        ← parallel specialist agents
-analyst     (agent)
(agent)      
   |
implementation-planner (agent)     ← 30-day plans for GO opportunities
        |
   Notion DB + markdown output
```

### Agents

| Agent | Model | Role |
|-------|-------|------|
| `bookmark-orchestrator` | Opus | Pipeline coordinator — classifies, dispatches, merges, ranks, writes output |
| `opportunity-analyst` | Opus | Deep research, revenue validation, plausibility scoring, GO/NO-GO recommendation |
| `implementation-planner` | Opus | 30-day execution roadmaps for opportunities with plausibility >= 7 |
| `skill-compiler` | Sonnet | Extracts techniques/tools and maps them to existing projects |

### Skills

| Skill | Purpose |
|-------|---------|
| `process-bookmarks` | Main entry point — orchestrates the full pipeline |
| `bookmark-capture` | Browser automation to read and parse X bookmarks |

## Requirements

- [Claude Code](https://claude.ai/code) desktop app or CLI
- [Claude in Chrome](https://chromewebstore.google.com/detail/claude-in-chrome/) extension — installed and connected to your Claude Code session
- Logged into [X (Twitter)](https://x.com) in Chrome
- [Notion](https://www.notion.so) MCP server connected (optional — for database output; markdown output works without it)

## Installation

### 1. Create a Cowork Project

Open Claude Code (desktop app or CLI) and create a new project, or open an existing one where you want bookmark processing available.

### 2. Add the Plugin

In your Cowork project, go to **Customizations** (the `+` next to "Personal plugins") and choose one of:

- **Add marketplace** — enter the GitHub repo `WillyV347/twitterBookmarks` to register the marketplace, then enable the **Bookmark Income Engine** plugin
- **Upload plugin** — clone this repo locally and point to the `plugins/bookmark-income-engine` directory

Once added, the `/process-bookmarks` skill and all 4 agents will appear under your project's Skills and Agents.

### 3. Connect Required Tools

Make sure these MCP servers are connected in your project:

- **Claude in Chrome** — for browser automation (bookmark capture)
- **Notion** — for database output (optional but recommended)

### 4. Set Up a Scheduled Task

The real power is running this on autopilot. In your Cowork project, create a scheduled task:

1. Go to **Scheduled Tasks** (or use `/schedule`)
2. Create a new task with a name like `bookmark-triage`
3. Set a cron schedule (e.g., twice a week: `0 9 * * 1,4`)
4. Set the prompt:
   ```
   Run /process-bookmarks 30. After completion, summarize the top 3 opportunities.
   ```

The engine will run on schedule, capture your latest bookmarks, research opportunities, and populate your Notion pipeline — no manual intervention needed.

## Usage

Once installed, run manually anytime:

```
/process-bookmarks        # Process up to 30 bookmarks (default)
/process-bookmarks 50     # Process up to 50 bookmarks
```

Or let your scheduled task handle it automatically.

## Output

- **Notion**: "Bookmark Income Pipeline" database with board, table, and list views
- **Markdown**: `output/run-YYYY-MM-DD.md` — full run archive
- **Dedup tracker**: `output/.last-run` — prevents reprocessing bookmarks across runs

## License

MIT
