---
inclusion: fileMatch
fileMatchPattern: '*.yaml|*.yml|deploy*.sh|serverless.yml'
---

# Deployment Standards

Loaded when working on infrastructure or deploy scripts. Keeps deployments
repeatable, safe for data, and consistent across projects.

## Deploy scripts

Every deployable component has a shell script. Conventions:

- Start with `set -e` so any failed step aborts the deploy.
- Accept the target stage as an argument, defaulting to `app`
  (e.g. `STAGE=${1:-app}`).
- Install dependencies if missing before deploying.
- After deploy, **retrieve and print the live URLs / IDs** from stack outputs so
  the user gets a working link, not just "done".
- Echo clear progress with the step being run, and end with next-step hints
  (test URL, how to view logs, how to invalidate cache).
- Keep destructive actions (data seeding, table creation) behind an explicit flag
  (e.g. `--with-sample-data`), never automatic.

## CloudFront deploy ordering

1. Deploy the ACM certificate stack in `us-east-1` (DNS-validated) and wait for it.
2. Read the cert ARN from the cert stack's outputs.
3. Deploy the CloudFront + S3 + Route53 stack in the primary region, passing the
   cert ARN as a parameter.
4. Sync static files to S3.
5. Create a CloudFront invalidation (`/*`) and note it takes 1-3 minutes.

Look up the Route53 hosted zone ID dynamically from the parent domain rather than
hardcoding it.

## Data safety

- Deploys update code and infrastructure only. They must never drop or overwrite
  DynamoDB data.
- Treat data tables as persistent resources. If a table already exists, reuse it.
- Only run seed/sample-data scripts on first-time setup, behind a flag.

## Rate limiting at deploy time

- API Key projects: the Usage Plan (burst/rate) is part of the API stack.
- Serverless Framework projects without keys: include
  `serverless-api-gateway-throttling` and set stage-level limits.
- Never deploy a public API with no throttling.

## Frontend deploy checklist

Before considering a UI deploy complete, confirm:

- [ ] Full favicon set present (`.ico`, `.svg`, PNG sizes, `apple-touch-icon.png`)
- [ ] `manifest.json` present and referenced
- [ ] CloudFront cache invalidated after the file sync
- [ ] Custom domain resolves over HTTPS

## Verification

- After deploy, hit a real endpoint (e.g. `curl` the health/list route) to confirm
  it responds, don't rely on the stack reporting success.
- Know where the logs are: `serverless logs -f <fn> --stage <stage>` or CloudWatch
  for the function's log group.

## Documentation

Each project keeps its deployment story in `DEPLOYMENT.md` (or a `README.md`
section): prerequisites, first-time setup, update workflow, and troubleshooting.
