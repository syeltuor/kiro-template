---
inclusion: fileMatch
fileMatchPattern: ["**/*.yaml", "**/*.yml", "**/*.sh"]
---
<!-- kiro-template v2.0.0 -->

# Deployment Standards

Reference implementation: `templates/scripts/deploy.sh`.

## Always deploy through the project's deploy script

- Never hand-run `aws s3 sync`, `aws cloudformation deploy` or an invalidation.
  If the script is awkward, **fix the script**, then run it.
- Two modes: **default = content only** (sync `staging/`, invalidate CloudFront);
  **`--infra`** = lint, deploy stacks in order (`--no-fail-on-empty-changeset`),
  then content.
- `set -euo pipefail`; validate arguments before any AWS call.
- `PROJECT` / `STAGE` overridable from a gitignored `.env`; nothing
  account-specific hardcoded.
- **Bucket names, distribution IDs, API URLs, client IDs come from stack
  outputs**, via a helper that aborts on an empty output.
- Look up the hosted zone ID from the parent domain.
- End by printing the live URL and "invalidation takes 1-3 minutes".
- Destructive or one-off actions (seeding, backfill) in their own scripts.

## `staging/` is the live site

- Synced as-is with `--delete`: no build step, copy step or file list.
- Mock-ups, raw assets and drafts go in `ARCHIVE/`, **never** `staging/`
  (everything in it is published).
- Guard: abort if `staging/index.html` is missing (wrong path + `--delete` would
  wipe the site).
- Generated config (e.g. `staging/js/config.js` with API URL and Cognito client
  ID) is written by the deploy script and gitignored.

## S3 sync rules

```bash
aws s3 sync staging/ "s3://$BUCKET" --delete \
  --exclude ".DS_Store" --exclude "*/.DS_Store" \
  --cache-control "public, max-age=0, s-maxage=86400, must-revalidate"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths '/*'
```

- Also exclude fixtures and other dev-only folders.
- **Never pass a blanket `--content-type`**: the CLI's per-file guess gets `.js`,
  `.css`, `.json`, `.svg`, `.png`, `.ico` right; a blanket type breaks them.
- That Cache-Control means browsers always revalidate, CloudFront caches a day,
  and the per-deploy `/*` invalidation (1-3 minutes) publishes new content.

## Lint and package

- `cfn-lint` (pinned, in a gitignored `.venv`) plus
  `aws cloudformation validate-template` on every template (certificate template
  in `us-east-1`): `templates/scripts/lint.sh`. Errors abort; report warnings.
- A private, retained **artifacts bucket** (lifecycle expiry, TLS-only) holds code
  for `aws cloudformation package`. Templates use `Code: ../services/<name>/src`.
  Purge `__pycache__` first.
- API Gateway only redeploys when the `AWS::ApiGateway::Deployment` logical ID
  changes: bump `ApiDeploymentV2`, `V3`, ... whenever resources, methods,
  authorizers or gateway responses change.

## Stack order (typical)

1. Certificate (`us-east-1`, DNS-validated, 2-5 minutes).
2. Artifacts bucket.
3. Data (DynamoDB, retained).
4. Auth (Cognito), only if needed.
5. API (packaged).
6. Jobs (packaged, EventBridge Scheduler).
7. CloudFront + private S3 + Route53 (needs API/Cognito origins for the CSP).
8. Content sync + invalidation.

A new distribution takes 5-15 minutes. Deploys that outlive an agent's command
timeout: `nohup ... > deploy.log 2>&1 &` and poll.

## Data safety

Deploys never drop or overwrite data. Tables, user pools and buckets are
`DeletionPolicy: Retain`. Failed stack in `ROLLBACK_COMPLETE`: see
`lessons-learned.md`.

## Post-deploy checks

Run them and report actual output; "stack succeeded" is not enough.

- [ ] `curl -sI https://<domain>`: `HTTP/2 200` with the security headers
- [ ] Right `content-type` per asset type (html, css, js, json, svg, png, ico)
- [ ] `http://` 301s to `https://`
- [ ] TLS 1.2+ (`openssl s_client -tls1_2 ...`), valid cert for the domain
- [ ] **A and AAAA** records resolve (`dig +short A/AAAA`)
- [ ] **401 on every protected route** with no or a bogus token
- [ ] CORS preflight returns only the site origin and allowed headers
- [ ] Cognito login: PKCE curl test (`cognito.md`)
- [ ] Favicon set (`templates/scripts/make-icons.sh`) and `manifest.json` served
- [ ] Desktop and mobile screenshots: `templates/scripts/screenshots.sh`

## Logs, npm scripts, docs

- `scripts/logs.sh <component>` tails `/aws/lambda/<project>-<component>`
  (`aws logs tail --follow`).
- npm scripts (Node projects): `deploy` (content only), `deploy:infra`,
  `deploy:app`, `deploy:prod`; `logs` / `logs:app` / `logs:prod`; `get-urls`;
  `lint`, `test`; setup scripts as needed (`setup:params`, `create-user`,
  `backfill`).
- README (or `DEPLOYMENT.md`): prerequisites, first-time setup incl. user-only
  steps, update workflow, troubleshooting.
