# Plan: Smarter Conflict Resolution + Diary Memo Architecture Refactor

Branch: master | Date: 2026-06-16

<!-- /autoplan restore point: /Users/aurora/.gstack/projects/Workflow-Calendar/master-autoplan-restore-20260616-150755.md -->

## Background

Existing system: GitHub Actions cron (every 15 min, CST 08:00–23:59) sends `{since,
diary_memo_id?}` to Claude Routine → Routine reads flomo memos, creates Calendar events.
Separate 8am cron creates `#Diary Jun. 16 时间记录` header in flomo; Aurora writes
time records into it throughout the day. Prior autopilots shipped: base sync, conflict
detection rules, diary header, mail workflow.

Two problems to solve in this round:
1. Conflict/overlap resolution still requires Aurora to manually fix common cases.
   New rules needed: 15-min granularity, prefer edit over create, infer full-day
   timeline, auto-replace placeholder health events.
2. Routine does a broad memo_search for the diary memo every 15 min even when nothing
   has changed. GH Actions can poll the memo directly and only call the Routine when
   there is actually new content.

---

## Feature 1: Revised Processing Model (SKILL.md Steps 1–5 rework)

### 1a. 15-Minute Time Granularity

All inferred times must snap to the nearest 15-minute mark.
Exception: explicitly stated clock times that end in a non-15-multiple (e.g., "10:07
上课" — keep if the user wrote it; round otherwise).

Rule: after extracting `start_time` and `end_time` in Step 2, apply:
```
start_time = round_to_nearest_15(start_time)
end_time   = round_to_nearest_15(end_time)
```
Rounding: .00/.15/.30/.45 are already aligned; otherwise round to closest.
Fixed scheduled activities (classes with explicit start/end in the schedule) are exempt.

### 1b. Full-Day Timeline Inference (Step 3 rework)

**Current Step 3** fetches Calendar events just for conflict checking.

**New Step 3**: Build a complete picture of the day BEFORE deciding what to create/edit.

1. Fetch all events for `target_date` (already done)
2. Classify each existing event:
   - **Placeholder health** (`[flomo:]` NOT in description AND summary matches sleep/
     shower/meal keywords): 睡觉、睡眠、洗漱、洗澡、早饭、午饭、晚饭、早餐、午餐、晚餐.
     These are pre-populated recurring events that WILL be replaced by actual times.
   - **System-logged** (`[flomo:]` in description): created by a previous Routine run.
     Treat as ground truth for what's already recorded.
   - **Scheduled fixed** (学习-课程 calendar, or recurring class in description):
     Cannot be overridden without explicit user instruction.
   - **Other user events**: treat as real, prefer to keep.

3. Overlay the flomo memo's parsed activities onto the existing events.
   The goal: produce a MERGED timeline where:
   - Placeholder health events are updated with actual times from flomo
   - Existing system-logged events are not re-created (dedup)
   - Gaps in existing events are filled from flomo
   - Where flomo and existing events align (same activity, same slot) → edit, not create

### 1c. Edit-First Rule (Step 4/5 rework)

**Core principle**: prefer `update_event` over `create_event` whenever the activity
maps to an existing event that can be updated.

Updated priority table for Step 4:

| Priority | Situation | Action |
|----------|-----------|--------|
| 1 | Dedup: description already has `[flomo:<memo_id>]` | Skip |
| 2 | flomo activity matches an existing **placeholder health** event (same type, overlapping time, no `[flomo:]`) | `update_event` with actual times + `[自动更新: 实际时间]` tag |
| 3 | flomo activity matches an existing **system-logged** event with same memo_id | Skip (already processed) |
| 4 | Existing event is **自习课** (placeholder) | Absorb: see existing 自习课 rules |
| 5 | flomo activity is a **co-activity** of an existing scheduled event (默认活动原则) | `update_event` on existing: append `（co-activity）` to summary |
| 6 | flomo activity overlaps an existing event with **same activity name** | Skip (same thing) |
| 7 | No overlap at all | `create_event` |
| 8 | Overlap with a **non-placeholder** event, activity is different | ⚠️ flag, new event |
| 9 | target_date > 24h ago | Skip |

**Placeholder health detection** (Priority 2):
- No `[flomo:]` in description
- Summary contains any of: 睡觉、睡眠、洗漱、洗澡、早饭/早餐、午饭/午餐、晚饭/晚餐
- Apply semantic match: flomo says 洗漱 → existing event 洗漱 is a match; flomo says 吃晚饭 → 晚饭/晚餐 match
- Read-only calendar guard still applies (学习-课程 → skip update, fall to Priority 8)

### 1d. No Duplicate Entries

Strong rule: before ANY `create_event`, scan ALL existing events for the day
(not just overlapping ones) for `[flomo:<memo_id>]`. If found: skip entirely.
Also scan for same summary + same time slot — if a system-logged event already
covers this slot with the same activity, skip.

### 1e. Files changed

- `SKILL.md`: Step 2 (add 15-min rounding), Step 3 (full-day timeline inference,
  event classification), Step 4 (new priority table), Step 5 (edit-first rule)
- `test/memos.json`: new test cases for 15-min rounding, placeholder replacement,
  edit-over-create

---

## Feature 2: Diary Memo Architecture Refactor

### 2a. Problem

- Routine currently runs two memo_searches every 15 min (regular window + `#Diary` sweep)
- The `#Diary` sweep runs even when Aurora hasn't written anything since the last poll
- GH Actions can poll the memo directly, know when it changed, and only call the
  Routine when there is new content → fewer unnecessary Routine invocations

### 2b. GH Actions side (flomo-diary-trigger.yml)

After creating the diary memo at 8am, capture the memo ID from the API response:
```bash
MEMO_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])")
```
Store as a GitHub Repository Variable via GitHub API:
```bash
gh api repos/{owner}/{repo}/actions/variables/DIARY_MEMO_ID_TODAY \
  --method PATCH -f value="$MEMO_ID"
gh api repos/{owner}/{repo}/actions/variables/DIARY_MEMO_LAST_UPDATED \
  --method PATCH -f value="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```
`DIARY_MEMO_LAST_UPDATED` = creation timestamp → represents "zero content" baseline.

### 2c. GH Actions side (flomo-logger-trigger.yml)

Each 15-min run:
1. Read `${{ vars.DIARY_MEMO_ID_TODAY }}` and `${{ vars.DIARY_MEMO_LAST_UPDATED }}`
2. Fetch current memo metadata from flomo REST API:
   ```bash
   curl -s "https://flomoapp.com/api/v1/memo/${DIARY_MEMO_ID}" \
     -H "Authorization: Bearer ${{ secrets.FLOMO_API_TOKEN }}"
   ```
   Extract `updated_at` from response.
3. If `updated_at > DIARY_MEMO_LAST_UPDATED`:
   - Include `"diary_memo_id": "$DIARY_MEMO_ID"` in the Routine webhook body
   - Update `DIARY_MEMO_LAST_UPDATED` variable to the new `updated_at`
4. If unchanged (or `DIARY_MEMO_ID_TODAY` is empty/stale): call Routine without
   `diary_memo_id` (old behavior — Routine falls back to regular search only)

**Fallback** if `GET /api/v1/memo/{id}` doesn't exist (unconfirmed endpoint):
- Always pass `diary_memo_id` in webhook. Rely on existing dedup to skip
  unchanged content. Lose the "only-when-updated" optimization but keep
  the `memo_batch_get` token savings.

### 2d. SKILL.md Step 1 rework

**Remove** entirely:
```
调用二：memo_search(keywords="#Diary", start_date=<今日 00:00:00+08:00>)
```

**Add** conditional:
```
若 webhook payload 含 diary_memo_id 字段：
  调用二：memo_batch_get(ids=[diary_memo_id])
  将结果合并入 memo 列表（按 id 去重）
  # memo_batch_get 是按 ID 直接取，比 memo_search 快且省 token
```

### 2e. Required GitHub Variables (not Secrets)

| Variable | Updated by | Value |
|---|---|---|
| `DIARY_MEMO_ID_TODAY` | flomo-diary-trigger at 8am | Memo ID string |
| `DIARY_MEMO_LAST_UPDATED` | flomo-diary-trigger (init) + flomo-logger-trigger (on update) | ISO 8601 UTC timestamp |

GH Repository Variables (not Secrets) are readable in workflows via `${{ vars.NAME }}`.
Writable via `gh api repos/.../actions/variables` using GITHUB_TOKEN with
`permissions: variables: write` in the workflow.

### 2f. Files changed

- `SKILL.md` (Step 1: remove Call 2, add conditional memo_batch_get)
- `.github/workflows/flomo-diary-trigger.yml` (capture memo ID + init variables)
- `.github/workflows/flomo-logger-trigger.yml` (poll diary memo, conditional body)
- `routine-config.md` (document new variables + architecture diagram)
- `Makefile` (add `make health` check for DIARY_MEMO_ID_TODAY variable)

---

## Premises

1. The flomo `POST /api/v1/memo/` response body contains `data.id` (the memo ID)
2. A flomo REST endpoint for fetching a single memo by ID exists — `GET /api/v1/memo/{id}`
   or similar. If not, fallback is always-pass (see 2c above).
3. GitHub Repository Variables (`vars.*`) can be written from within a workflow using
   `gh api repos/.../actions/variables` with `permissions: variables: write`
4. `memo_batch_get` is cheaper/faster than `memo_search` for fetching a known memo ID
5. Placeholder health events in Aurora's calendar do NOT have `[flomo:]` in description
   (safe heuristic — they are pre-populated manually or via Google Calendar recurring events)
6. The LLM in the Routine can make semantic match judgments for placeholder detection
   (睡觉↔睡眠, 吃饭↔午饭, etc.) without a complete hard-coded keyword list

---

## NOT in scope

- Retroactive cleanup of existing ⚠️-flagged events
- Detecting Google Calendar recurring events via the `recurrence` API field
- Reducing Routine calls for the regular `since`-based search (only diary memo gets update-gating)
- Handling multiple diary memos in one day

---

## Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|----------------|-----------|-----------|----------|
