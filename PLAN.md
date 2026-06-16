# Plan: Smart Conflict Resolution + Daily Diary Header + Mail→Calendar Patch

Branch: master | Date: 2026-06-15

<!-- /autoplan restore point: /Users/aurora/.gstack/projects/Workflow-Calendar/master-autoplan-restore-20260615-202411.md -->

## Background

Existing system: GitHub Actions cron (every 15 min, CST 08:00–23:59) triggers a
claude.ai Routine that reads flomo memos tagged 时间记录 and creates Google Calendar
events. Prior autoplan (2026-06-12) shipped the base system.

## Features

### Feature 1: Smart Conflict Resolution (SKILL.md — Step 4)

**Problem:** Current Step 4 flags overlapping events with `⚠️ 时间重叠` / `⚠️ 冲突，请确认`
but leaves human review required. For common cases (class period with side activity,
transit with activity, 自习课 repurposed), the right resolution is deterministic.

**New rules:**

1. **自习课 absorption** — If the conflicting existing event is `自习课` (free study
   period), it's a placeholder with no fixed content. Relabel it to the incoming
   activity: `自习: [activity]` and reclassify to the appropriate calendar category.
   Do NOT create a separate event; replace the 自习课 entry.

2. **Default-activity principle** — For concurrent activities A and B, determine which
   would happen regardless:
   - "If I didn't do B, would I still do A?" → If yes, A is the default.
   - "If I didn't do A, would I still do B?" → If yes, B is the default.
   - Categorize by the DEFAULT activity; list the others in parentheses.
   
   Examples:
   - 坐车 + 听播客 → `路上（听播客）` [transit happens regardless]
   - 散步 + 听歌 → `舒缓（听歌）` [the walk was the plan]
   - 文学课 (teacher didn't lecture) + 做其他事 → `文学课（做其他事）` [class was scheduled]
   - 飞机 + 看书/睡觉 → split only if flight is 10+ hours; otherwise `路上（看书）`
   
   When the default activity is the category, the calendar category stays as the
   default activity's calendar. All co-activities go in the summary's parentheses.

3. **Scope:** Apply to all overlapping pairs. 自习课 rule (above) has priority.
   Current ⚠️ flags: reserved only for genuinely ambiguous conflicts where the
   default activity cannot be determined.

**Files changed:** `SKILL.md` (Step 4 section)

---

### Feature 2: Daily Flomo Diary Header (new GitHub Actions cron)

**Problem:** Aurora wants to start each day with a pre-created flomo memo as a diary
header so she can add time records throughout the day. Currently she has to manually
open flomo and create it.

**Desired behavior:**
- Every morning at ~08:00 CST (00:00 UTC), automatically create a flomo memo:
  ```
  #Diary Jun. 15 时间记录
  ```
- Date format: `Jun. 15` (abbreviated month, day without zero-padding)
- Aurora then edits/appends to this memo throughout the day using flomo's native edit
- The existing 时间记录 routine reads from this same memo (memo_search picks it up)

**Implementation approach:** Direct flomo REST API call from GitHub Actions.
- No new Claude routine needed — just one curl call
- flomo memo creation: `POST https://flomoapp.com/api/v1/memo/` with Bearer token
- New GitHub Secret needed: `FLOMO_API_TOKEN` (same token value as the MCP `fmcp_*` token)
- New workflow file: `.github/workflows/flomo-diary-trigger.yml`

**Files changed:**
- `.github/workflows/flomo-diary-trigger.yml` (new)
- `routine-config.md` (update to document new secret + cron)

---

### Feature 3: Apply mail→calendar patch

**Problem:** A sibling Mail→Calendar workflow was built in a separate patch
(`mailtocalendar.patch`) and needs to be applied to this repo and pushed.

**Patch summary (from diff):**
- `.github/workflows/mail-to-calendar-trigger.yml` — new cron (every 30 min, PST hours)
- `SKILL-mail.md` — Claude Routine system prompt for Gmail → Calendar parsing
- `routine-config-mail.md` — non-secret setup reference
- `README-mail.md` — overview + flowchart
- `test/expected-parse.md` — 5 seed emails → expected events validation set
- `README.md` — link to sibling workflow appended

**Files changed:** 6 new/modified files from the patch

---

## Premises

1. The claude.ai Routine's system prompt (SKILL.md) can be updated by editing the
   file in this repo and re-pasting into the Routine's system prompt field
2. flomo REST API supports memo creation via `POST /api/v1/memo/` with Bearer token
3. The `fmcp_*` token used by flomo MCP also works for REST API auth
4. GitHub Actions can make outbound HTTPS calls to flomoapp.com
5. The mailtocalendar.patch applies cleanly to the current HEAD
6. Mail→Calendar workflow uses separate secrets (MAIL_CAL_ROUTINE_*) that won't
   conflict with the existing Flomo time-logger secrets

---

## NOT in scope

- Automatically re-pasting SKILL.md into the claude.ai Routine (manual step per routine-config.md)
- Building a UI for conflict review
- Retroactive conflict resolution on existing Calendar events
- flomo's edit/append API (Aurora does this manually throughout the day)

---

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|----------------|-----------|-----------|----------|
| 1 | CEO | Add `[自动合并: A→B]` tag in event description when conflict auto-resolved | Mechanical | P1 Completeness | Silent merge loses audit trail; tag lets Aurora spot-check | Silent merge |
| 2 | CEO | Add parsing guard in Step 2: skip `#Diary …` line when extracting activities | Mechanical | P1 Completeness | Diary header will be found by memo_search; must not be parsed as an activity | No guard |
| 3 | CEO | Add manual token verification step in routine-config.md before deploying diary cron | Mechanical | P3 Pragmatic | fmcp_* token scope for REST API untested despite user confidence | Skip verify |
| 4 | CEO | Feature 3 in same PR, separate git commit | Mechanical | P5 Explicit | User confirmed same-repo; separate commit keeps features reviewable | Single commit |
| 5 | Eng | 自习课 on read-only calendar → create new event on writable calendar + [自动合并: 自习课吸收]; don't touch original | Mechanical | P5 Explicit | update_event on 学习-课程（家庭日历）blocked by Step 0 read-only rule | update_event on read-only |
| 6 | Eng | [自动合并] tag at END of description: `…\| 置信度: X \| [自动合并: A→B]` | Mechanical | P5 Explicit | Tag before [flomo:id] would break dedup prefix scan | Tag at start |
| 7 | Eng | Add explicit tiebreakers: two scheduled classes→⚠️; transit→路上(co) always; slot wins content change | Mechanical | P1 Completeness | Symmetric concurrent activities otherwise deadlock the rule | No tiebreakers |
| 8 | Eng | Diary cron: check flomo JSON body code==0, not just HTTP status | Mechanical | P1 Completeness | flomo returns 200 with app-level error in body | HTTP-only check |
| 9 | Eng | 自习课 detection: substring match on `自习` not exact string | Mechanical | P5 Explicit | 晚自习/午自习 would miss exact match | Exact match only |
| 10 | Eng | Add 4 new test cases: diary-header-skip, 自习课-absorb, default-activity, [自动合并]-tag-position | Mechanical | P1 Completeness | Zero test coverage for all 3 new features | Defer tests |
| 11 | DX | Diary cron: set TZ=Asia/Shanghai before date command (CORRECTNESS BUG) | Mechanical | P5 Explicit | UTC runner produces yesterday's date for first 8h of CST day | UTC date |
| 12 | DX | Secret name FLOMO_API_TOKEN + inline doc "same value as fmcp_* token" | Mechanical | P5 Explicit | Two names for one token creates setup confusion | Rename to FLOMO_TOKEN |
| 13 | DX | Add curl one-liner to routine-config.md for manual token verification | Mechanical | P1 Completeness | Decision #3 said add manual test but no procedure written | Undocumented |
| 14 | DX | Show response body in diary workflow error path | Mechanical | P5 Explicit | HTTP status alone tells nothing about flomo app-level errors | Status-only |
| 15 | DX | Update Recovery Checklist in routine-config.md: add diary cron items | Mechanical | P1 Completeness | Recovery checklist becomes stale without diary cron items | Defer |
