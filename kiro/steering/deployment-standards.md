---
inclusion: fileMatch
fileMatchPattern: ["**/*.yaml", "**/*.yml", "**/*.sh"]
---
<!-- kiro-template v2.0.0 -->

# Deployment Standards

Loaded when working on CloudFormation templates or shell scripts. Keeps
deployments repeatable, safe for data, and consistent across projects. Reference
implementation: `templates/scripts/deploy.sh`.

## Always deploy through the project's deploy script

- Never hand-run `aws s3 sync`, `aws cloudformation deploy` or an invalidation.
  If the script is awkward for what you need, **fix the script**, then run it.
- One script, two modes:
  - **default = content only**: sync `staging/` to S3, then invalidate CloudFront.
  - **`--infra`**: lint, deploy the CloudFormation stacks in dependency order
    (`--no-fail-on-empty-changeset`), then the content phase.
- Start with `set -euo pipefail`. Validate arguments before any AWS call.
- `PROJECT` / `STAGE` variables (overridable from a gitignored `.env`); nothing
  account-specific is hardcoded.
- **Read bucket names, distribution IDs, API URLs, client IDs from stack outputs**,
  with a helper that aborts if an output is empty.
- Look up the Route53 hosted zone ID from the parent domain, never hardcode it.
- End by printing the live URL and the "invalidation takes 1-3 minutes" note.
- Keep destructive or one-off actions (seeding, backfill) in their own scripts,
  never automatic.

## `staging/` is the live site

- `staging/` **is** the website, synced as-is with `--delete`. No build step, no
  copy step, no hard-coded file list.
- Old mock-ups, raw design assets and drafts go in `ARCHIVE/` (or anywhere else),
  **never** in `staging/`, because everything in it gets published.
- Guard: abort if `staging/index.html` is missing (a wrong path plus `--delete`
  would wipe the site).
- Generated deploy-time config (e.g. `staging/js/config.js` with the API URL and
  Cognito client ID) is written by the deploy script and gitignored.

## S3 sync rules

```bash
aws s3 sync staging/ "s3://$BUCKET" --delete \
  --exclude ".DS_Store" --exclude "*/.DS_Store" \
  --cache-control "public, max-age=0, s-maxage=86400, must-revalidate"
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths '/*'
```

- Exclude `.DS_Store` (and fixtures or other dev-only folders).
- **Never pass a blanket `--content-type`**: the CLI guesses per file and gets
  `.js`, `.css`, `.json`, `.svg`, `.png`, `.ico` right. A blanket type breaks them.
- `Cache-Control: public, max-age=0, s-maxage=86400, must-revalidate`: browsers
  always revalidate, CloudFront caches for a day, and the per-deploy `/*`
  invalidation (1-3 minutes) makes new content visible.

## Lint before deploy

- `cfn-lint` (pinned, installed into a gitignored `.venv`) plus
  `aws cloudformation validate-template` on every template. The certificate
  template is validated in `us-east-1`. See `templates/scripts/lint.sh`.
- Errors abort the deploy; report warnings.

## Packaging Lambda code

- A private, retained **artifacts bucket** stack (lifecycle-expired objects,
  TLS-only policy) holds code for `aws cloudformation package`.
- Templates use `Code: ../services/<name>/src`; `package` zips and rewrites it.
  Purge `__pycache__` before packaging Python.
- API Gateway only creates a new deployment when the `AWS::ApiGateway::Deployment`
  logical ID changes. Bump the suffix (`ApiDeploymentV2`, `V3`, ...) whenever
  resources, methods, authorizers or gateway responses change.

## Stack order (typical)

1. Certificate (`us-east-1`, DNS-validated; waits 2-5 minutes).
2. Artifacts bucket.
3. Data (DynamoDB, retained).
4. Auth (Cognito), only if the site needs authentication.
5. API (packaged).
6. Jobs (packaged, EventBridge Scheduler).
7. CloudFront + private S3 + Route53 (needs API/Cognito origins for the CSP).
8. Content sync + invalidation.

A new CloudFront distribution takes 5-15 minutes. Long deploys can outlive an
agent's command timeout: run them with `nohup ... > deploy.log 2>&1 &` and poll.

## Data safety

- Deploys update code and infrastructure only. They never drop or overwrite data.
- Tables, user pools and buckets are `DeletionPolicy: Retain`.
- A stack in `ROLLBACK_COMPLETE` must be deleted before it can be re-created.
  Check for retained leftovers (user pool, Cognito domain prefix, bucket) first.

## Post-deploy checks (no data needed)

Run these and report the actual output. "Stack reported success" is not enough.

- [ ] `curl -sI https://<domain>` returns `HTTP/2 200` with the security headers
- [ ] Each asset type has the right `content-type` (html, css, js, json, svg, png, ico)
- [ ] `http://` redirects (301) to `https://`
- [ ] TLS 1.2+ (`openssl s_client -tls1_2 ...`) and a valid cert for the domain
- [ ] Route53 **A and AAAA** alias records resolve (`dig +short A/AAAA`)
- [ ] **401 on every protected route** without a token (and with a bogus one)
- [ ] CORS preflight returns only the site origin and only the allowed headers
- [ ] Cognito login page loads (authorize URL with an S256 PKCE challenge ends on
      the sign-in page; an unregistered `redirect_uri` gives `redirect_mismatch`)
- [ ] Favicon set and `manifest.json` served

## Frontend deploy checklist

- [ ] Full favicon set (`.ico`, `.svg`, PNG sizes, `apple-touch-icon.png`):
      `templates/scripts/make-icons.sh`
- [ ] `manifest.json` present and referenced
- [ ] CloudFront cache invalidated after the sync
- [ ] Desktop and mobile screenshots checked: `templates/scripts/screenshots.sh`

## Privacy check before every push

Run `scripts/privacy-check.sh` (template in `templates/scripts/`) before pushing.
It fails closed. See `github-standards.md`.

## Logs

`scripts/logs.sh <component>` tails `/aws/lambda/<project>-<component>` with
`aws logs tail --follow`. Log groups are declared in the stack with
`RetentionInDays`.

## Documentation

Each project keeps its deployment story in the README (or `DEPLOYMENT.md`):
prerequisites, first-time setup (including the user-only steps), update workflow,
and troubleshooting.
