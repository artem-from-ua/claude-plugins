# Retroscope Config Schema Reference

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `storageDir` | string | — | Absolute path to storage git repo (REQUIRED) |
| `remoteUrl` | string | `""` | Git remote URL for pushing reports |
| `language` | string | `"en"` | Report language code (e.g. "en", "uk", "de") |
| `timezone` | string | system TZ | IANA timezone name (e.g. "Europe/Kyiv") |
| `model` | string | `"haiku"` | Report model: `haiku`, `sonnet`, or `inherit` |
| `extractMode` | boolean | `true` | Pre-filter sessions to text-only content |
| `sessionSource` | string | `"logs"` | `/retro session` data source: `logs` (full JSONL, reliable) or `context` (current conversation, fast but may be incomplete) |
| `suggestRetroOnExit` | boolean | `true` | Show /retro reminder in SessionEnd hook |
| `scope` | string | `"project"` | Report scope: `project` (current project only) or `all` (cross-project daily reports) |
| `autoPush` | boolean | `false` | Git push after each report commit |
