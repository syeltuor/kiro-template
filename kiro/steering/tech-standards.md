---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Technical Standards

Core architecture and conventions for serverless web applications. Applies to all
work in this project unless a more specific instruction overrides it. Related
always-on standards: `security-standards.md`, `cost-standards.md`,
`github-standards.md`, `process-standards.md`.

## Architecture

- Serverless-first. Compute is AWS Lambda; no long-running servers, no VPC unless a
  requirement truly needs one (a VPC usually drags in NAT or endpoint costs, see
  `cost-standards.md`).
- Data is DynamoDB with on-demand (`PAY_PER_REQUEST`) billing.
- APIs are AWS Lambda behind API Gateway (REST), with CORS restricted to the
  app's own origin.
- Prefer small, single-purpose Lambdas and stacks over one monolith when the app
  has distinct components (e.g. API, scheduled ingest job). Don't split further
  than the components justify.

## Project shapes

**The standard is shape A.** Use it unless the owner explicitly asks for something
else. A0 is A with the API removed. B is an exception, not an equal option.

| Shape | What it is | When |
|---|---|---|
| **A. Static UI + separate API (standard)** | HTML/CSS/JS in a private S3 bucket behind CloudFront; the API is its own Lambda + API Gateway stack | Default for every app that needs an API |
| **A0. Static-only public site** | S3 + CloudFront only. No API Gateway, no Lambda, no Cognito, no authorizer | Public sites with no server-side data |
| **B. Single Web Function (exception)** | One Lambda Web Function serves the HTML and the API routes from one HTTP server | Only when the owner explicitly asks for it, or for a tiny app where a CDN plus a separate API is clearly overkill |

In plain English: in **A** the browser downloads the site from CloudFront (fast,
cached, almost free) and calls a separate API for data, so UI and API deploy
independently. **A0** is the same site with no API at all; it is the cheapest
possible shape and needs no auth. In **B** one function answers every request,
pages and data alike: one thing to deploy, but no CDN cache unless you put
CloudFront in front, and every UI change redeploys the function.

See `frontend-hosting.md` for A and A0.

### Shape B: Lambda Web Functions (exception shape)

Lambda Web Functions (announced late 2026) run an ordinary port-listening Node.js
HTTP server (Express, Hono, Fastify, Next.js and similar) with no event-handler
rewrite and no adapter. Check the current
[Web Functions docs](https://docs.aws.amazon.com/lambda/latest/dg/web-functions.html)
before choosing this shape; the facts below were true at the time of writing.

- **Region check first.** At launch Web Functions were available only in a few
  regions (including `eu-west-1`, Ireland) and **not in `eu-west-2` (London)**, our
  primary region. If London is still unsupported, the nearest option is
  `eu-west-1`. That is a deliberate deviation from the primary-region rule: record
  it in the design and get the user's approval before building.
- **Runtime check.** Use the Node.js runtime Web Functions currently support (check
  the docs; at launch it was a single Node.js version on Arm64 only).
- **Server contract.** The server must listen on the `host:port` given in the
  `AWS_LAMBDA_HTTP_ENDPOINT` environment variable. Run locally by setting it
  yourself (e.g. `127.0.0.1:3000`).
- **Concurrency and billing.** One execution environment serves many concurrent
  requests. Billing is requests + active CPU time + memory **for as long as the
  execution environment exists** + data transfer. I/O wait is cheap, but memory
  is metered for the environment's life, so verify idle cost (see
  `cost-standards.md`) before assuming it is near zero.
- **Deploy.** The CLI (`aws lambda-web deploy --name <name> --code <dir>`) creates
  revisions and endpoints and supports weighted traffic shifting between
  revisions. For anything that lives longer than a prototype, define it in
  CloudFormation (`AWS::Lambda::WebFunction`, `WebFunctionEndpoint`,
  `WebFunctionRevision`; verify the properties against the CloudFormation
  reference, they are new) and deploy it through the project's deploy script.
- **Endpoint access.** The CLI's default endpoint auth type is public
  (`ApplicationManaged`). For a site behind CloudFront, use `IamAuth` on the
  endpoint plus CloudFront OAC (origin type `lambda`), with a resource policy that
  lets only your distribution invoke it. Note the endpoint domain stays reachable
  on the internet; unsigned requests are rejected. Verify against the Web Functions
  docs before relying on any of this.
- **Custom domain, TLS, security headers, WAF**: put CloudFront in front.
- **Throttling**: set an endpoint rate limit and a cap on execution environments.
- **No VPC.** Web Functions support VPCs, but don't put this shape in one (NAT and
  interface endpoints break the idle-cost target).
- **Auth** follows the same decision table in `security-standards.md`. Public
  read-only: no auth. Private data or any write: Cognito, with tokens validated in
  the app (CloudFront forwards the `Authorization` header to an `IamAuth`
  endpoint; verify against the Web Functions docs).
- **Single-region.** Web Functions offer multi-region with latency routing; don't
  turn it on for small apps.

## Infrastructure as code

- Raw **CloudFormation** YAML is the only IaC standard. No SAM transforms, no
  third-party frameworks, no CDK unless the owner asks.
- Lambda code is packaged with `aws cloudformation package` into a private
  artifacts bucket (`Code: ../services/<name>/src` in the template).
- Every stack declares useful **Outputs** (API URLs, distribution IDs, table names)
  and exports them as `${AWS::StackName}-<OutputKey>` so other stacks and scripts
  can consume them.
- Never hardcode values that belong in parameters (domain names, bucket names,
  hosted zone IDs, cert ARNs, runtimes).
- Lint every template before deploying (`templates/scripts/lint.sh`).

## Regions and runtimes

- Primary region: `eu-west-2` (London). Exceptions (e.g. shape B) need user
  approval and must be written down.
- ACM certificates for CloudFront **must** be created in `us-east-1` (CloudFront
  only reads certs from there). All other resources stay in the primary region.
- Lambda runtimes: use the **latest Lambda-supported Node.js runtime** for APIs and
  the **latest supported Python runtime** for jobs/scrapers. Check AWS's current
  supported-runtimes list at project start. Never hard-code a version in docs.
  In templates the runtime is a `Runtime` parameter. Keep runtimes current and
  never ship on a deprecated one.
- Prefer `arm64` for Lambda (cheaper per GB-second).
- Set **memory and timeout explicitly** on every function. Don't rely on defaults.

## Configuration and secrets

- Config and secrets live in **SSM Parameter Store** under `/<project>/...`
  (standard tier: `String` for config, `SecureString` for secrets). Details in
  `security-standards.md`.

## Scheduled jobs and data ingest

- Schedule jobs with **EventBridge Scheduler** and set `ScheduleExpressionTimezone`
  explicitly (e.g. `Europe/London`). Without it cron runs in UTC and drifts an hour
  across daylight saving.
- Ingest is **idempotent and cursor-based**: store a "fetched up to" cursor per
  source, re-fetch a small overlap, and write with upserts so a rerun never
  duplicates data.
- Every data-pull job has a **backfill mode** that loads history in bounded
  chunks (e.g. month by month) separately from the incremental run.
- No async retries for scheduled jobs (`MaximumRetryAttempts: 0`) when the next
  run self-heals. Retries only duplicate work.
- **No `ReservedConcurrentExecutions` by default.** Small or new accounts can have
  a Lambda concurrency quota as low as 50, and Lambda keeps 50 unreserved, so any
  reservation fails at deploy time. Guard against overlap with idempotent writes
  or a DynamoDB conditional-write lock instead.

## DynamoDB conventions

- On-demand billing. **One table per app** (PK/SK single-table design) unless items
  have genuinely different lifecycles or access controls.
- Choose keys around the primary access pattern; add GSIs only for real queries.
- Tables are persistent: `DeletionPolicy: Retain`, `UpdateReplacePolicy: Retain`,
  deletion protection on. Deploys update code and infra, never wipe data.
- Table names carry the stage (e.g. `{{Project}}Data-app`).

## IAM

- Least privilege always. Grant only the specific actions on the specific table,
  parameter or log-group ARNs a function needs; never `dynamodb:*` or
  `Resource: "*"` for data access.
- Each Lambda gets its own role scoped to its job.

## Naming and stages

- Stacks: `{{project}}-{{component}}` (e.g. `myapp-cloudfront`, `myapp-api`).
- Functions: `{{project}}-{{purpose}}` (e.g. `myapp-api`, `myapp-ingest`).
- Stages: `app` (and optionally `prod` / `dev`). **A single-stage app is fine**;
  make `deploy:prod` an alias rather than inventing a second environment nobody
  uses.

## Cost

Target: **under $1/month idle per app**. See `cost-standards.md` for the rules and
the list of things not to create without approval.

## npm script conventions (Node projects)

Provide consistent scripts so every project feels the same:

- `deploy` (content only), `deploy:infra`, `deploy:app`, `deploy:prod`
- `logs` / `logs:app` / `logs:prod`
- `get-urls` (print live endpoint/URLs after deploy)
- `lint`, `test`
- component-specific setup scripts as needed (`setup:params`, `create-user`,
  `backfill`)
