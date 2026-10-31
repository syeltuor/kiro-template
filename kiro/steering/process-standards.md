---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Process Standards

How work gets done well. Short on purpose.

## Verify external services live, first

- Before designing around an external API or AWS feature, **call it for real**
  and keep an `api-verification.md` note with what you saw. Real responses beat
  docs. Typical surprises: data missing for some regions, products that can't be
  listed, per-request date-range caps, a different base URL per account, a feature
  missing in your region.

## Flow

requirements -> design -> design review -> plan -> build -> code review ->
deploy -> verify

- Keep the notes for each step in `.agents/<project>/` and **commit them**
  (identifiers scrubbed; see `github-standards.md`).
- A review loop that keeps finding new issues should be **closed deliberately**:
  carry the remaining findings into the plan as required changes rather than
  looping forever.

## User-only steps are explicit pauses

Entering secrets, confirming an email, approving a console setting, raising a
quota: stop, give the **exact commands** to run (secrets at a `read -rs` prompt),
and wait for the user to confirm.

## Done means verified

- Never claim done on "command exited 0". Check the real success criteria with
  real checks: `curl` the URL, run the tests, take screenshots, recalculate the
  numbers independently.
- **Never dismiss a user-reported issue** without reproducing it first.
- Report what was verified and, separately, what was not (and why).

## Scope and safety

- Ask before expanding scope, adding paid resources (`cost-standards.md`) or
  making account-level changes.
- Deploy only through the project's deploy script (`deployment-standards.md`).
