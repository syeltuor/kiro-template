---
inclusion: auto
name: lessons-learned
description: Real gotchas for AWS serverless apps - API Gateway CORS errors, Cognito managed login and branding, Lambda runtimes and concurrency, CloudFormation rollbacks, CloudFront caching, Lambda Web Functions, zsh quoting and git. Use when debugging or building these.
---
<!-- kiro-template v2.0.0 -->

# Lessons Learned

Gotchas hit on real projects. Each one cost time once.

## API Gateway and Lambda

- **Browser "CORS errors" from API Gateway are usually not CORS.** Check the
  status code first: a **403 on the preflight** with `MissingAuthenticationToken`
  means the route or method isn't deployed (bump the `ApiDeploymentV<n>` logical
  ID); a **502** means the Lambda crashed or timed out (read its logs). Add CORS
  headers to `DEFAULT_4XX`/`DEFAULT_5XX` gateway responses so real errors are
  readable in the browser.
- **Recent Node.js Lambda runtimes only support async handlers.** Callback-style
  `(event, context, callback)` handlers fail; use `export const handler = async
  (event) => { ... }`.
- **A low Lambda concurrency quota makes reserved concurrency impossible.** Small
  or new accounts can have a quota of 50, and Lambda must keep 50 unreserved, so
  any `ReservedConcurrentExecutions` fails with CREATE_FAILED. Use idempotent
  writes or a conditional-write lock instead.

## CloudFormation

- **`ROLLBACK_COMPLETE` stacks must be deleted before re-creating.** And a failed
  Cognito stack can leave a **retained user pool** (`DeletionPolicy: Retain`)
  behind, plus its **globally unique domain prefix**. List and clean them up
  (`aws cognito-idp list-user-pools`, `describe-user-pool-domain`) before retrying.

## CloudFront

- **Stale UI after deploy** = missing `/*` invalidation or missing
  `Cache-Control` on the objects. Invalidation takes 1-3 minutes.

## Cognito managed login (v2) and branding

- With managed login v2 (`UserPoolDomain` `ManagedLoginVersion: 2`, Essentials
  plan), an app client **without a branding style shows an error page** instead
  of the sign-in form. Always create an `AWS::Cognito::ManagedLoginBranding` for
  every client, with `DependsOn` the `UserPoolDomain`.
- Use `UseCognitoProvidedValues: false` when you supply `Settings`. The
  `Settings` document is **partial**: Cognito merges unspecified keys with its
  defaults, so set only what you change.
- The branding schema is **strict**. `link` and `input` are top-level
  **`componentClasses`**, not `components`. Putting them under `components`
  fails with `$.components.link UnknownProperty` and rolls the stack back.
- **Discover the real schema** instead of guessing: create a temporary client with
  `UseCognitoProvidedValues: true`, run
  `aws cognito-idp describe-managed-login-branding-by-client --user-pool-id <id>
  --client-id <id> --return-merged-resources`, and copy the key paths.
- **Test the whole flow with curl**: build an authorize URL with a real S256 PKCE
  challenge, follow redirects (`curl -sL`), and check the final page is the
  sign-in page with the expected `<title>`. An unregistered `redirect_uri` must
  give `redirect_mismatch`.
- The Cognito **domain prefix is globally unique per region**. Check it's free
  before creating the stack.
- Keep branding colours (`RRGGBBAA` hex) in stack parameters.
- See the pre-create checklist in `templates/cognito-stack.yaml`.

## Lambda Web Functions

- The server must listen on the `host:port` in `AWS_LAMBDA_HTTP_ENDPOINT`. Set
  it yourself to run locally.
- Limited regions and runtimes at launch (London wasn't one of them; only one
  Node.js runtime, Arm64). Check the current docs before choosing the shape.
- The CLI's default endpoint is public (`ApplicationManaged`). Use `IamAuth` and
  CloudFront OAC to make CloudFront the only caller.
- Memory is billed for the life of each execution environment: verify idle cost.

## Data ingest

- **Upstream data APIs lag (often by a day) and have gaps.** Store a cursor per
  source, write idempotently, re-fetch an overlap, and show "data up to <time>"
  in the UI so a lag doesn't look like a bug.

## Tooling

- **zsh: `!` inside double quotes triggers history expansion.** Single-quote
  generated passwords and secrets, or better, enter them at a `read -rs` prompt.
- **`git ls-remote` is not a visibility check.** Stored credentials make a private
  repo look reachable, and an empty repo returns nothing. Use the GitHub API (see
  `github-standards.md`).
- **Headless Chrome won't screenshot below ~500px width** (`--window-size` is
  clamped). For mobile screenshots set the viewport through the DevTools
  protocol: `templates/scripts/cdp-shot.mjs`.
