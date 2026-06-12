# Testing SKILL.md Changes

## How to test a SKILL.md edit (2-minute feedback loop)

1. Open Claude Code in this repo
2. Paste this prompt:

```
Read SKILL.md in this repo. Then act as the Routine described in it.

Use the following test memo as input (pretend the flomo MCP returned this):

<paste one object from test/memos.json here>

Do NOT actually write to Google Calendar. Instead, show me the JSON array you would
produce in Step 2, and the list of create_event calls you would make in Step 5.
Compare your output to the "expected" field in the test case.
```

3. Check: does the `target_date` match? Are the times right? Is the confidence level correct?

## Running against real flomo data (dry run)

```
Read SKILL.md. Act as the Routine. Use the flomo MCP to fetch the most recent
时间记录 memo (no time filter — just get the latest one).

Run Steps 1–4 of SKILL.md but DO NOT call create_event in Step 5.
Instead, show me the list of events you would create.
```

## Full live test (writes to Calendar)

```
Read SKILL.md. Execute it fully. Use since="<yesterday 00:00 UTC>".
```

Run this once on a day you already have data for, then inspect the teal events in Google Calendar.

## Editing parsing rules

The duration inference table is in the `## Default Duration` section of SKILL.md.
Add rows to match your activity patterns. Format: `| activity keyword | N minutes |`

After editing, re-run the dry-run test above against a real recent memo to verify.
