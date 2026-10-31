---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Technical Standards

## Architecture

- Serverless: Lambda, no long-running servers. **No VPC** unless truly required
  (NAT/endpoint costs).
- DynamoDB on-demand (`PAY_PER_REQUEST`). APIs: Lambda + API Gateway (REST).
- One Lambda and stack per distinct component (e.g. API, ingest job), no finer.
- UI: no inline scripts or styles (strict CSP).

## Project shapes

| Shape | What | When |
|---|---|---|
| **A. Static UI + separate API (standard)** | Private S3 + CloudFront site; API is its own Lambda + API Gateway stack; each deploys independently | Every app that needs an API |
| **A0. Static-only** | S3 + CloudFront only; no API, Lambda or auth | Public sites with no server-side data |
| **B. Single Web Function (exception)** | One Lambda Web Function serves HTML and API; no CDN cache unless CloudFront is in front; UI change = redeploy | Only if the owner asks, or a tiny app where A is clearly overkill (`web-functions.md`) |

## Infrastructure as code

- Raw **CloudFormation** YAML only: no SAM, CDK, Serverless Framework or other
  frameworks unless the owner asks.
- Export useful **Outputs** (API URLs, distribution IDs, table names) as
  `${AWS::StackName}-<OutputKey>`.
- Parameters, never hard-coded: domains, bucket names, hosted zone IDs, cert ARNs,
  runtimes.

## Regions and runtimes

- `eu-west-2` (London); exceptions need written user approval. ACM certs for
  CloudFront **must** be in `us-east-1`.
- Latest Lambda-supported Node.js (APIs) and Python (jobs); check AWS's list at
  project start. `Runtime` is a template parameter; no versions in docs.
- `arm64`; memory and timeout explicit on every function.

## Naming and stages

- Stacks `{{project}}-{{component}}` (`myapp-api`); functions
  `{{project}}-{{purpose}}` (`myapp-ingest`).
- Stage `app` (optional `prod`/`dev`); with one stage `deploy:prod` is an alias.

## DynamoDB

- **One table per app** (PK/SK) unless lifecycles or access controls differ. Keys
  follow the primary access pattern; GSIs only for real queries.
- `DeletionPolicy` and `UpdateReplacePolicy: Retain`, deletion protection on;
  deploys never wipe data. Table names carry the stage (`{{Project}}Data-app`).
