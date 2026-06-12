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

| Secret | Description |
|--------|-------------|
| `CLAUDE_ROUTINE_WEBHOOK_URL` | Webhook URL from the claude.ai Routine settings |
| `CLAUDE_ROUTINE_API_KEY` | API key / auth token for the webhook (from same page) |

**Workflow file:** `.github/workflows/flomo-logger-trigger.yml`
**Schedule:** `*/15 0-15 * * *` UTC = every 15 min, 08:00–23:59 CST

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

## Recovery Checklist (after a long gap)

- [ ] Verify flomo MCP token is still valid: run a memo_search in Claude Code
- [ ] Verify Google Calendar MCP works: run a list_events in Claude Code
- [ ] Re-paste SKILL.md into the claude.ai Routine (if Routine was deleted)
- [ ] Confirm GitHub Secrets are still set: repo → Settings → Secrets and variables → Actions
- [ ] Trigger a manual test run: GitHub Actions → Flomo Time Logger Trigger → Run workflow
- [ ] Write a test flomo memo containing "时间记录" and confirm a teal Calendar event appears within 20 min
