---
inclusion: auto
name: process-standards
description: How work gets done and verified - starting a new project or feature, requirements, design, design review, planning, code review, build, testing, deploying, verifying work, integrating or calling an external API or new AWS feature, asking the user to enter secrets or do a manual step, approvals, is it done, finished, reporting results, user-reported bugs. Use when planning, reviewing, verifying or reporting on work.
---
<!-- kiro-template v2.0.0 -->

# Process Standards

## Verify external services live, first

Before designing around an external API or AWS feature, **call it for real** and
record what you saw in `api-verification.md`. Typical surprises: data missing for
some regions, unlistable products, per-request date-range caps, a per-account base
URL, a feature missing in your region.

## Flow

requirements -> design -> design review -> plan -> build -> code review ->
deploy -> verify

- Notes per step in `.agents/<project>/`, **committed** (identifiers scrubbed).
- Close a review loop that keeps finding issues deliberately: carry the remaining
  findings into the plan as required changes.

## User-only steps are explicit pauses

Entering secrets, confirming an email, approving a console setting, raising a
quota: stop, give the **exact commands** (secrets at a `read -rs` prompt), wait
for confirmation.

## Done means verified

- Not "exited 0": check the real criteria (`curl` the URL, run tests, screenshots,
  recalculate numbers independently).
- **Reproduce a user-reported issue** before dismissing it.
- Report what was verified and, separately, what wasn't and why.
