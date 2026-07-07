# Changelog

All notable changes to the Bookmark Income Engine plugin are documented here.

## [1.2.0]

### Fixed
- **Deterministic config resolution.** The `process-bookmarks` skill and command
  no longer look only at the hardcoded `../../config.yaml` inside the plugin's own
  install directory. In Cowork / plugin-mount contexts that directory is mounted
  read-only, so a config saved there could never persist — every fresh session
  found nothing, concluded "not configured," and in at least one case hallucinated
  a config reconstructed from the Notion database schema.

### Changed
- `config.yaml` is now resolved by checking candidate locations in priority order:
  1. `$BOOKMARK_ENGINE_CONFIG` (environment variable override)
  2. `~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml`
     (documented stable path in the user's workspace)
  3. `<plugin-root>/config.yaml` (last-resort fallback, explicitly labeled as
     non-persistent between sessions)
- When no config is found, the skill now reports **exactly which paths were
  checked** instead of a generic "no config.yaml found," and is explicitly told
  never to reconstruct config from the Notion schema.
- `config.example.yaml` header now states plainly that it must be copied to a path
  outside the plugin install directory and documents the recommended stable path
  and the resolution order.
