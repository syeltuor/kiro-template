<!-- kiro-template v2.0.0 -->

# Changelog

All notable changes to the Kiro AWS Serverless Standards. Versions follow
semantic versioning; `main` is always the latest release.

## [2.0.0]

Lessons from a real build (a Cognito-protected dashboard with scheduled ingest)
folded back into the standards.

### Added

- `VERSION` file and this changelog. Every steering file and template carries a
  `kiro-template v2.0.0` marker.
- Steering:
  - `cost-standards.md` (always on): target **under $1/month idle per app**, a
    table of resources not to create without approval (with the cheaper
    alternative), idle + busy-month estimates in every design, log retention,
    right-sized schedules, a budget alarm, check the real bill after a week.
  - `github-standards.md` (always on): private by default, visibility checked
    via the GitHub API (not `git ls-remote`), short-lived branches, conventional
    commits, per-command identity, everything that defines the project in git,
    fail-closed privacy check before every push, HTTPS pushes.
  - `process-standards.md` (always on): verify external services live first,
    requirements → design → review → plan → build → review → deploy → verify,
    explicit user-only pauses, "done" means verified.
  - `lessons-learned.md` (`inclusion: auto`): API Gateway "CORS" errors, async
    handlers, concurrency quota vs reserved concurrency, zsh `!`, `ls-remote`,
    stale UI, upstream data lag, **Cognito managed login branding**, headless
    Chrome mobile screenshots, `ROLLBACK_COMPLETE` and retained Cognito leftovers,
    Lambda Web Functions.
- Security: an **auth decision table** (none / Cognito / API key / shared token),
  a standard Cognito configuration (admin-create-only, Essentials, PKCE public
  client, pinned callback URLs, authorizer on every non-public route), SSM
  Parameter Store rules (user enters secrets at a `read -rs` prompt; agents only
  check existence; personal identifiers treated as secrets).
- Tech: plain-English comparison of shapes A (standard), A0 (static-only) and the
  exception shape B; EventBridge Scheduler with explicit timezone; idempotent
  cursor-based ingest with a backfill mode; no reserved concurrency by default;
  explicit memory/timeout; one table per app; single-stage apps are fine.
- Deployment: `staging/` is the live site; content-only default deploy with
  `--infra` for stacks; output-driven, guarded, lint-first; sync rules
  (`--delete`, no blanket `--content-type`, `Cache-Control`); post-deploy checks
  that need no data.
- Frontend: CloudFront response headers policy with a strict CSP; Cache-Control
  guidance; static-only and authenticated-site variants.
- Templates: `cognito-stack.yaml` (managed login v2 + `ManagedLoginBranding` with
  colour parameters and the pre-create checklist), `api-stack.yaml`,
  `data-stack.yaml`, `budget-stack.yaml`, `artifacts-stack.yaml`, `gitignore`,
  `.env.example`.
- Scripts (`templates/scripts/`): `deploy.sh`, `lint.sh`, `privacy-check.sh`,
  `setup-params.sh`, `create-user.sh`, `get-urls.sh`, `logs.sh`, `dev.sh`,
  `make-icons.sh` + `make-ico.py`, `screenshots.sh` + `cdp-shot.mjs`, `_lib.sh`.
- Installer: `--scripts` (scripts + `.env.example` + `.gitignore`), prints the
  installed version, writes `.kiro/.standards-version`, `STANDARDS_REF`.
- **Exception shape B: a single Lambda Web Function** serving pages and API, only
  when the owner asks for it. Includes the region caveat (not available in London
  at the time of writing; `eu-west-1` needs user approval), the
  `AWS_LAMBDA_HTTP_ENDPOINT` contract, endpoint access via `IamAuth` + CloudFront
  OAC, no VPC, and the memory-billing idle-cost caveat. Replaces v1's
  "embedded frontend in Lambda via the Serverless Framework".

### Changed

- Cognito is now the default for authenticated sites; **only** sites that need
  authentication get it. API keys and the shared header token are demoted to
  limited-use options (rows c and d).
- Runtimes: no version numbers anywhere in prose. Use the latest Lambda-supported
  Node.js / Python runtime; in templates `Runtime` is a parameter.
- Cost target tightened from "a few dollars a month" to under $1/month idle.
- `certificate-stack.yaml` and `cloudfront-stack.yaml` refreshed from a working
  deployment: the CloudFront stack now creates the private, retained site bucket
  itself, adds a security headers policy with a `ContentSecurityPolicy`
  parameter and a TLS-only bucket policy; both take a `Project` parameter;
  outputs renamed (`CertificateArn`, `DistributionId`, `SiteBucketName`).
- `deploy-cloudfront.sh` and `deploy-api.sh` are **deprecated** in favour of
  `templates/scripts/deploy.sh`; they were updated to the v2 stack parameters.
- `requireApiKeyAuth.md` / `requireTokenAuth.js` carry a "limited use" header;
  the API-key-in-`localStorage` admin page pattern was removed (admin pages use
  Cognito).
- `deployment-standards.md` `fileMatchPattern` is now an array,
  `["**/*.yaml", "**/*.yml", "**/*.sh"]`, so it also loads for `scripts/*.sh`.
  Kiro's steering docs document the array form for multiple patterns; v1's
  `'*.yaml|*.yml|...'` was not a valid glob.
- All always-on steering files now have explicit `inclusion: always` front matter.
- `install.sh`: `STANDARDS_REF` (branch or tag) replaces `STANDARDS_BRANCH`
  (still accepted, with a deprecation warning); default ref `main`; help works
  when piped through `curl | bash`.

### Removed

- **Serverless Framework**, everywhere: the v1 "Serverless Framework v3 is
  acceptable" rule, the `serverless-api-gateway-throttling` plugin guidance,
  `serverless.yml` in the deployment `fileMatchPattern`, `serverless logs`, and
  the Serverless-based embedded-frontend shape. Raw CloudFormation is the only
  IaC standard.
  **Throttling is not removed.** Only the plugin is gone, because it was only
  needed by Serverless Framework apps. Every API still gets stage-level throttling,
  set natively in CloudFormation (`MethodSettings` `ThrottlingRateLimit` /
  `ThrottlingBurstLimit` on the API Gateway stage; see `templates/api-stack.yaml`
  and `security-standards.md`), plus usage plans for API-key callers.
- Hard-coded runtime versions (v1 README and project README template).
- Personal example project names from the README and naming examples.

### Fixed

- `install.sh` default repo pointed at unresolved `{{GH_USER}}/{{REPO}}`
  placeholders (also in the README curl examples); now
  `https://github.com/syeltuor/kiro-template.git`.
- README tree showed `.kiro/steering`; the repo actually stores `kiro/steering`.
- Typo "perfer" and the duplicated "(latest version available)" line in
  `tech-standards.md`.

### Migration notes (v1 -> v2)

In a project that installed v1 standards:

1. **Re-install** the steering with `--force` (backups are made):
   `curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh | bash -s -- . --force`
   This adds `cost-standards.md`, `github-standards.md`, `process-standards.md`
   and `lessons-learned.md`, and updates the four v1 files.
2. **Delete** after reviewing the diff: the `*.bak-<timestamp>` copies, and any
   `serverless.yml` / Serverless plugins if you migrate that project to
   CloudFormation (or keep them knowingly: v2 no longer covers them).
3. **Add** (optional): `--scripts` for `scripts/deploy.sh` and friends,
   `.env.example`, a baseline `.gitignore`; deploy `budget-stack.yaml` once per
   account.
4. **Templates changed shape**: the v2 CloudFront stack creates its own bucket.
   Don't redeploy an existing v1 CloudFront stack with the v2 template without
   planning the bucket move (v1 stacks referenced an existing bucket by name).
5. **Auth**: projects on the API-key or header-token option for admin pages
   should plan a move to Cognito.
6. **Pull v1 instead**: use the v2 installer with `STANDARDS_REF=v1` (branch) or
   `STANDARDS_REF=v1.0.0` (tag). The v1 installer itself has an unresolved
   default repo URL, so don't run `v1/install.sh` directly.
   `curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh | STANDARDS_REF=v1 bash`

## [1.0.0]

Initial standards: tech, security, frontend-hosting and deployment steering;
CloudFront + certificate templates; API-key and header-token auth helpers;
installer.
