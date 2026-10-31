---
inclusion: auto
name: lessons-learned
description: Real gotchas and troubleshooting for AWS serverless apps - CORS errors, API Gateway 403 MissingAuthenticationToken and 502 errors, Lambda handler not async, reserved concurrency CREATE_FAILED, ROLLBACK_COMPLETE stacks, retained Cognito user pool, stale UI after deploy and CloudFront cache, Cognito managed login branding errors, Lambda Web Functions, upstream data lag, zsh history expansion, git ls-remote, headless Chrome mobile screenshots. Use when debugging or building these.
---
<!-- kiro-template v2.0.0 -->

# Lessons Learned

## API Gateway and Lambda

- **Browser "CORS errors" from API Gateway are usually not CORS.** Check the
  status: **403 on the preflight** with `MissingAuthenticationToken` = route not
  deployed (bump the `ApiDeploymentV<n>` logical ID); **502** = Lambda crashed or
  timed out (read its logs). `DEFAULT_4XX`/`DEFAULT_5XX` CORS headers make real
  errors readable.
- **Recent Node.js runtimes only support async handlers**: callback-style
  `(event, context, callback)` fails; use `export const handler = async (event) =>`.
- **`ReservedConcurrentExecutions` CREATE_FAILED**: the account quota is 50 and
  Lambda keeps 50 unreserved (`data-ingest.md`).

## CloudFormation

- **`ROLLBACK_COMPLETE` stacks must be deleted before re-creating.** A failed
  Cognito stack can leave a **retained user pool** and its **globally unique
  domain prefix**: clean up (`aws cognito-idp list-user-pools`,
  `describe-user-pool-domain`) before retrying.

## CloudFront

- **Stale UI after deploy** = missing `/*` invalidation or missing
  `Cache-Control`. Invalidation takes 1-3 minutes.

## Cognito branding and Web Functions

- Managed login branding error pages and schema errors: `cognito.md`.
- Lambda Web Functions region, runtime, endpoint and cost gotchas:
  `web-functions.md`.

## Data ingest

- **Upstream data APIs lag (often a day) and have gaps**: cursor, overlap,
  idempotent writes and "data up to <time>" in the UI (`data-ingest.md`).

## Tooling

- **zsh: `!` in double quotes triggers history expansion.** Single-quote secrets,
  or better, use a `read -rs` prompt.
- **`git ls-remote` is not a visibility check**: stored credentials make a private
  repo reachable, an empty repo returns nothing. Use the GitHub API
  (`github-standards.md`).
- **Headless Chrome won't screenshot below ~500px width** (`--window-size` is
  clamped). Set the viewport via DevTools protocol: `templates/scripts/cdp-shot.mjs`.
