# Changelog

All notable changes to the Bookmark Income Engine plugin are documented here.

## [1.3.0]

### Added
- **Self-bootstrapping config.** When no `config.yaml` is found at any candidate
  location, the `process-bookmarks` skill/command now copies `config.example.yaml`
  to the stable, persistent path
  (`~/Documents/Claude/Projects/AI Projects/bookmark-income-engine/config.yaml`),
  creating the directory if needed, then stops and asks the user to fill in real
  values. This closes the last manual gap: a fresh session in a read-only plugin
  mount can now leave behind a persistent config instead of dead-ending.

### Changed
- The skill now explicitly refuses to run the pipeline against placeholder config.
  If the resolved config still contains the example projects (`my-saas-app` /
  `my-automation-bot`), it is treated as "not yet configured" and execution stops
  — guarding against both fabricated configs and unedited templates.

> Note: an already-installed plugin must be updated/reinstalled from the
> marketplace for these changes to take effect; merging to the repository does not
> refresh a cached plugin install in a running session.

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
