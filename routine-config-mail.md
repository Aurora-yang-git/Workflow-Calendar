# Routine Configuration Record — Mail → Calendar

Non-secret reference for recreating the claude.ai automation.

## Cloud Routine (claude.ai)

| Field | Value |
|-------|-------|
| Name | Mail to Calendar |
| System prompt | Contents of `SKILL-mail.md` in this repo |
| MCP connectors | **Gmail + Google Calendar** (both required) |
| Trigger type | Webhook (inbound HTTP POST) |
| Webhook body | `{ "trigger": "mail_to_calendar" }` |

**Google Calendar / Gmail MCP:** connected via OAuth at claude.ai. Re-authorize if events stop appearing or label reads fail.

## Gmail label queue (the heart of the dedup)

1. In Gmail, create two labels: **`Cal-Sync`** (the to-do queue) and **`Cal-Done`** (processed).
2. Choose how mail enters the queue:
   - **Auto (recommended):** Gmail → Settings → Filters and Blocked Addresses → Create a new filter →
     `From: yixuany@stanford.edu` (your forwarding source) → Create filter → **Apply label: `Cal-Sync`**.
     Now every email you forward to yourself auto-queues. Tighten with `subject:(Fw OR Confirmed OR Newsletter)` if you forward non-event mail too.
   - **Manual:** after forwarding an event email, just apply the `Cal-Sync` label yourself.
3. The routine removes `Cal-Sync` and adds `Cal-Done` after processing, so re-runs never double-create.

> Label names have no spaces on purpose — `label:Cal-Sync` works directly in Gmail search. The routine still resolves the label **IDs** via `list_labels()` because `label_message`/`unlabel_message` require IDs.

## GitHub Actions

**Secrets required** (repo → Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `MAIL_CAL_ROUTINE_WEBHOOK_URL` | Webhook URL from the claude.ai Routine settings |
| `MAIL_CAL_ROUTINE_API_KEY` | API key / auth token for the webhook (same page) |

**Workflow file:** `.github/workflows/mail-to-calendar-trigger.yml`
**Schedule:** `*/30 15-23,0-6 * * *` UTC = every 30 min, ~08:00–23:30 **Pacific** (you're at Stanford). Adjust the hour range if you want it bounded differently. The job is idempotent, so running off-hours is harmless.

## Recovery Checklist (after a gap)

- [ ] Gmail MCP works: run a `search_threads(query="label:Cal-Sync")` in Claude
- [ ] Google Calendar MCP works: run a `list_calendars()` in Claude
- [ ] `Cal-Sync` / `Cal-Done` labels still exist; filter still active
- [ ] Re-paste `SKILL-mail.md` into the claude.ai Routine (if it was deleted)
- [ ] GitHub Secrets still set
- [ ] Manual test: GitHub Actions → Mail to Calendar Trigger → Run workflow
- [ ] Forward one test event email, apply `Cal-Sync`, confirm an event appears within ~30 min and the mail flips to `Cal-Done`
