# Technical Standards

Core architecture and conventions for serverless web applications. Applies to all
work in this project unless a more specific instruction overrides it.

## Architecture

- Serverless-first. Compute is AWS Lambda; no long-running servers.
- Data is DynamoDB with on-demand (`PAY_PER_REQUEST`) billing unless a workload
  clearly justifies provisioned capacity.
- APIs are AWS Lambda behind API Gateway (REST), with CORS restricted to the
  app's own origin.
- Prefer many small, single-purpose Lambdas and stacks over one monolith when the
  app has distinct components (e.g. public API, admin API, scheduled jobs).

## Two supported project shapes

Pick one per project, perfer option 1 unless stated

1. **CloudFront + S3 static UI + separate API (default).** Static frontend hosted
   in S3 behind CloudFront; APIs deployed as separate Lambda + API Gateway stacks.
   See `frontend-hosting.md`. Use for anything beyond a trivial UI.
2. **Embedded frontend in Lambda (lightweight).** HTML/CSS/JS embedded into a
   single Lambda that also serves the API, deployed with the Serverless Framework.
   Use only for very small internal/family apps.

## Infrastructure as code

- Default to raw **CloudFormation** YAML stacks for CloudFront/static-hosting
  projects (fine-grained control, no plugin drift).
- The **Serverless Framework v3** is acceptable for API-centric or
  embedded-frontend apps. If used, pin plugin versions.
- Every stack must declare useful **Outputs** (API URLs, distribution IDs, table
  names) and export them so other stacks and scripts can consume them.
- Never hardcode values that belong in parameters (domain names, bucket names,
  hosted zone IDs, cert ARNs).

## Regions and runtimes

- Primary region: `eu-west-2` (London).
- ACM certificates for CloudFront **must** be created in `us-east-1` (CloudFront
  only reads certs from us-east-1). All other resources stay in the primary region.
- Lambda runtimes: **Node.js 20.x** for APIs, **Python 3.12** for scrapers/jobs.
  Keep runtimes current; don't ship on deprecated versions.

## DynamoDB conventions

- On-demand billing by default.
- Choose partition/sort keys around the primary access pattern; add Global
  Secondary Indexes only for real query needs.
- Treat data tables as persistent. Deploys update code and infra, never wipe data.
- Table names carry the stage where the table is environment-specific
  (e.g. `CalendarEvents-${stage}`); shared reference tables can be stage-less.

## IAM

- Least privilege always. Grant only the specific actions on the specific table
  or resource ARNs a function needs, never `dynamodb:*` or `Resource: "*"`.
- Each Lambda gets its own role scoped to its job.

## Naming

- Stacks: `{{project}}-{{component}}` (e.g. `swimming-times-cloudfront`).
- Stages: `app` / `prod` (and optional `dev`).
- Functions: `{{project}}-{{purpose}}` (e.g. `swimming-times-api`).

## Cost

- These apps should cost a few dollars a month at small scale. Favour on-demand
  pricing, CloudFront `PriceClass_100`, and free-tier-friendly patterns.
- Flag any design choice likely to cause a step-change in cost.

## npm script conventions (Node projects)

Provide consistent scripts so every project feels the same:

- `deploy`, `deploy:app`, `deploy:prod`
- `logs` / `logs:app` / `logs:prod`
- `get-urls` (print live endpoint/URLs after deploy)
- component-specific setup scripts as needed
