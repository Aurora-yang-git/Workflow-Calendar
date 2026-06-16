# Routine Configuration Record

Non-secret reference for recreating the claude.ai automation after a gap.

## Cloud Routine (claude.ai)

| Field | Value |
|-------|-------|
| Name | Flomo Time Logger |
| System prompt | Contents of `SKILL.md` in this repo |
| MCP connectors | flomo + Google Calendar (both required) |
| Trigger type | Webhook (inbound HTTP POST) |
| Webhook body | `{ "trigger": "flomo_time_record", "since": "<ISO 8601 UTC>" }` |

**flomo MCP config:**
```json
{
  "type": "streamable-http",
  "url": "https://flomoapp.com/mcp",
  "headers": { "Authorization": "Bearer <FLOMO_TOKEN>" }
}
```
Token format: `fmcp_*`. Get from flomo Settings → Open API.

**Google Calendar MCP:** Connected via OAuth at claude.ai. Re-authorize if events stop appearing.

## GitHub Actions

**Secrets required:**

| Secret | Description | Token format |
|--------|-------------|--------------|
| `CLAUDE_ROUTINE_WEBHOOK_URL` | Webhook URL from the claude.ai Routine settings | URL |
| `CLAUDE_ROUTINE_API_KEY` | API key / auth token for the webhook (from same page) | — |
| `FLOMO_API_TOKEN` | flomo open API token — **same value** as the `fmcp_*` token used by the flomo MCP connector. Get from flomo Settings → Open API. | `fmcp_*` |

**Repository Variables (not Secrets — set automatically by workflows, not manually):**

| Variable | Set by | Value | Purpose |
|----------|--------|-------|---------|
| `DIARY_MEMO_ID_TODAY` | `flomo-diary-trigger.yml` at 08:00 CST | flomo memo ID string | Logger passes this to Routine so it can use `memo_batch_get` instead of `memo_search` |
| `DIARY_MEMO_LAST_UPDATED` | `flomo-diary-trigger.yml` at 08:00 CST | ISO 8601 UTC timestamp | Baseline for the Routine's `updated_at > since` check |
| `LAST_ROUTINE_SUCCESS_AT` | `flomo-morning-call.yml` / `flomo-evening-call.yml` on 2xx | ISO 8601 UTC timestamp | Used as `since` in the next webhook call — expands window correctly after a rate-limit gap |
| `RATE_LIMITED_UNTIL` | call workflows on 429 | ISO 8601 UTC timestamp | Call workflows skip all calls until after this time, then auto-resume |
| `PENDING_UPDATE_COUNT` | `flomo-logger-trigger.yml` on change; reset by call workflows on 2xx and by `flomo-diary-trigger.yml` daily | Integer string | Number of diary memo changes since last successful Routine call |
| `CALL_MORNING_UTC_HOUR` | `make set-call-times` | Integer string (UTC hour) | **Optional** — defaults to `4` (12:00 CST) if absent. Set via `make set-call-times`. |
| `CALL_EVENING_UTC_HOUR` | `make set-call-times` | Integer string (UTC hour) | **Optional** — defaults to `14` (22:00 CST) if absent. Set via `make set-call-times`. |

All variables are created automatically. On cold-start (variables absent): `since` falls back to 24h ago, `RATE_LIMITED_UNTIL` is treated as not set, `PENDING_UPDATE_COUNT` is treated as 0, and call times fall back to 12:00 / 22:00 CST.

**Workflow files:**

| File | Schedule | Purpose |
|------|----------|---------|
| `.github/workflows/flomo-logger-trigger.yml` | `*/15 0-15 * * *` UTC = every 15 min, 08:00–23:59 CST | Polls diary memo `updated_at`; increments `PENDING_UPDATE_COUNT` when changed. Does NOT call Routine. |
| `.github/workflows/flomo-diary-trigger.yml` | `0 0 * * *` UTC = 08:00 CST daily | Creates `#Diary Jun. 16 时间记录` header memo in flomo; resets `PENDING_UPDATE_COUNT=0` |
| `.github/workflows/flomo-morning-call.yml` | `0 2-15 * * *` UTC (hourly); fires Routine at `CALL_MORNING_UTC_HOUR` (default 04 UTC = 12:00 CST) | Morning Routine call if `PENDING_UPDATE_COUNT ≥ 1` |
| `.github/workflows/flomo-evening-call.yml` | `0 2-15 * * *` UTC (hourly); fires Routine at `CALL_EVENING_UTC_HOUR` (default 14 UTC = 22:00 CST) | Evening Routine call if `PENDING_UPDATE_COUNT ≥ 1` |

### Verify FLOMO_API_TOKEN before deploying the diary cron

Run this curl locally to confirm the token has write access to the REST API:

```bash
curl -s -X POST "https://flomoapp.com/api/v1/memo/" \
  -H "Authorization: Bearer <your-fmcp_*-token>" \
  -H "Content-Type: application/json" \
  -d '{"content": "#TEST delete me"}' | python3 -m json.tool
```

Expected success response: `{"code": 0, ...}`  
If you get `{"code": 401, ...}` or similar, the token doesn't have REST API write scope — contact flomo support or use a different token from Settings → Open API.

## Local Claude Code Task

**Purpose:** Writes Obsidian daily note each morning.
**Schedule:** 08:00 CST daily (next-morning catchup for prior day's Calendar events).
**Requires:**
- `OBSIDIAN_VAULT_PATH` env variable pointing to vault root (e.g. `/Users/aurora/Documents/Obsidian`)
- flomo + Google Calendar MCPs connected in Claude Code

**Task prompt to use with `/schedule`:**
```
Read Google Calendar events for yesterday (Asia/Shanghai timezone) and flomo memos
tagged 时间记录 from yesterday. Write a daily note to
$OBSIDIAN_VAULT_PATH/Daily/YYYY-MM-DD.md (where YYYY-MM-DD is yesterday's date in CST).

Format:
# YYYY-MM-DD

## 日程概览
(List all Calendar events. Mark [flomo]-prefixed events with 🤖.)

## flomo 时间记录
(Raw memo text from flomo for that day.)

## 备注
(Any events flagged with ⚠️ conflict or overlap. If none, omit this section.)

---
✅ Logger 运行于 HH:MM | 新增 X 个 🤖 事件 | 跳过 Y 个

If the file already exists, append to it instead of overwriting.
If OBSIDIAN_VAULT_PATH is not set, exit with an error message.
```

## Makefile commands

| Command | What it does |
|---------|-------------|
| `make health` | Check GH secrets exist, last 5 run statuses, flomo write access (requires `export FLOMO_API_TOKEN=fmcp_...` locally) |
| `make deploy` | Copy `SKILL.md` to clipboard + open claude.ai |
| `make logs` | Last 10 runs with timestamps and links |
| `make test-run` | Fire the polling workflow now and watch it complete |
| `make set-call-times` | Set call times (defaults: `MORNING=12 EVENING=22 OFFSET=8` for CST). Example for EST: `make set-call-times MORNING=12 EVENING=22 OFFSET=-5` |

## Recovery Checklist (after a long gap)

**Flomo → Calendar Routine:**
- [ ] Verify flomo MCP token is still valid: run a memo_search in Claude Code
- [ ] Verify Google Calendar MCP works: run a list_events in Claude Code
- [ ] Re-paste SKILL.md into the claude.ai Routine (if Routine was deleted)
- [ ] Confirm GitHub Secrets are still set: repo → Settings → Secrets and variables → Actions (`CLAUDE_ROUTINE_WEBHOOK_URL`, `CLAUDE_ROUTINE_API_KEY`, `FLOMO_API_TOKEN`)
- [ ] Check `RATE_LIMITED_UNTIL` variable: if it's set and in the past, delete it manually:
  ```bash
  gh api repos/Aurora-yang-git/Workflow-Calendar/actions/variables/RATE_LIMITED_UNTIL --method DELETE
  ```
- [ ] Check `PENDING_UPDATE_COUNT`: GitHub → repo Settings → Secrets and variables → Actions → Variables. A blank or `0` value is normal. A stuck nonzero value means the call workflows haven't fired yet.
- [ ] Trigger a manual polling run: GitHub Actions → Flomo Time Logger Trigger → Run workflow (should print "No diary memo ID yet" before 08:00 CST, or a change count otherwise)
- [ ] Trigger a manual morning call test: GitHub Actions → Flomo Morning Routine Call → Run workflow → set `force=true` input → confirm 2xx response and `LAST_ROUTINE_SUCCESS_AT` updates
- [ ] Trigger a manual evening call test: same for Flomo Evening Routine Call
- [ ] Write a test flomo memo into today's diary header and confirm the polling logger increments `PENDING_UPDATE_COUNT` within 20 min, then a teal Calendar event appears after the next call window
- [ ] If call workflows fire but print "No pending updates" unexpectedly: the polling logger may have missed the update. Manually set `PENDING_UPDATE_COUNT=1` and re-trigger with `force=true` to test the Routine path.

**Daily Diary Header Cron:**
- [ ] Verify `FLOMO_API_TOKEN` secret is still set (same token as flomo MCP `fmcp_*`)
- [ ] Run token verification curl above to confirm write access
- [ ] Trigger a manual run: GitHub Actions → Flomo Daily Diary Header → Run workflow
- [ ] Confirm a `#Diary <today> 时间记录` memo appears in flomo within 2 min
- [ ] Check memo date format is `Jun. 16` (abbreviated month, no zero-padding) not `Jun. 06`
