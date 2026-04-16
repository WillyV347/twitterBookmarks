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

- [Claude Code](https://claude.ai/code) with Cowork plugin support
- [Claude in Chrome](https://chromewebstore.google.com/detail/claude-in-chrome/) extension (connected)
- Logged into X (Twitter) in Chrome
- Notion MCP server connected (for database output)

## Installation

### As a Cowork Plugin

Add to your `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "willvowell-plugins": {
      "source": {
        "source": "github",
        "repo": "WillyV347/twitterBookmarks"
      }
    }
  },
  "enabledPlugins": {
    "bookmark-income-engine@willvowell-plugins": true
  }
}
```

Then restart Claude Code. The `/process-bookmarks` command will be available.

### Scheduled Runs

Pair with Claude Code's scheduled tasks for hands-free bookmark processing:

```
/schedule create bookmark-triage --cron "0 9 * * 1,4"
  --prompt "Run /process-bookmarks 30. After completion, summarize the top 3 opportunities."
```

## Usage

```
/process-bookmarks        # Process up to 30 bookmarks (default)
/process-bookmarks 50     # Process up to 50 bookmarks
```

## Output

- **Notion**: "Bookmark Income Pipeline" database with board, table, and list views
- **Markdown**: `output/run-YYYY-MM-DD.md` — full run archive
- **Dedup tracker**: `output/.last-run` — prevents reprocessing bookmarks across runs

## License

MIT
