<!-- kiro-template v2.0.0 -->

# Kiro AWS Serverless Standards v2

A copy-ready starter kit of Kiro steering files, CloudFormation templates and
project scripts for small serverless web apps on AWS. Install it into a project
and Kiro picks up the architecture, security, cost, GitHub and process rules
automatically.

> **What changed since v1**
>
> - **Cognito only when a site needs authentication.** A clear decision table:
>   public read-only sites need no auth; private data or any write uses Cognito.
> - **Idle cost under $1/month per app**, with a new always-on `cost-standards.md`.
> - **Serverless Framework dropped.** Raw CloudFormation is the only IaC standard.
> - **New steering**: `cost-standards`, `github-standards`, `process-standards`
>   and `lessons-learned` (real gotchas, incl. Cognito branding).
> - **No hard-coded runtime versions**: use the latest Lambda-supported runtimes.
> - **New templates and scripts**: Cognito, API, data, budget, artifacts stacks;
>   `deploy.sh`, `lint.sh`, `privacy-check.sh`, `setup-params.sh` and more.
> - Installer: `STANDARDS_REF` (branch or tag), `--scripts`, version stamp.
>
> Full list and migration notes: [CHANGELOG.md](CHANGELOG.md). Need v1? See
> [Versions](#versions).

## What's in here

```
kiro-template/
├── README.md                     # This file
├── VERSION                       # 2.0.0
├── CHANGELOG.md                  # What changed, and v1 -> v2 migration notes
├── PROJECT-README-TEMPLATE.md    # README to copy into a new project
├── install.sh                    # Installer (curl | bash, or run locally)
├── kiro/
│   └── steering/                 # Installed into <project>/.kiro/steering/
│       ├── tech-standards.md         # Architecture, shapes, runtimes, IaC (always)
│       ├── security-standards.md     # Auth decision table, Cognito, SSM, CORS (always)
│       ├── cost-standards.md         # < $1/month idle, what not to create (always)
│       ├── frontend-hosting.md       # S3 + CloudFront + OAC, headers, CSP (always)
│       ├── github-standards.md       # Visibility, branches, commits, privacy (always)
│       ├── process-standards.md      # How work gets done and verified (always)
│       ├── deployment-standards.md   # Deploy script rules (*.yaml, *.yml, *.sh)
│       └── lessons-learned.md        # Gotchas (auto: loaded when relevant)
└── templates/
    ├── certificate-stack.yaml        # ACM cert (us-east-1) for CloudFront
    ├── cloudfront-stack.yaml         # Private S3 + CloudFront (OAC, CSP) + Route53
    ├── artifacts-stack.yaml          # Private bucket for packaged Lambda code
    ├── data-stack.yaml               # DynamoDB on-demand table, retained
    ├── cognito-stack.yaml            # User pool, managed login v2 + branding, PKCE client
    ├── api-stack.yaml                # REST API, Cognito authorizer, throttling, one Lambda
    ├── budget-stack.yaml             # Monthly AWS Budget + email alert
    ├── gitignore                     # Baseline .gitignore
    ├── .env.example                  # Key names for the scripts (no values)
    ├── deploy-cloudfront.sh          # DEPRECATED (use scripts/deploy.sh)
    ├── deploy-api.sh                 # DEPRECATED (use scripts/deploy.sh)
    ├── auth/
    │   ├── requireApiKeyAuth.md      # API key + usage plan (limited use)
    │   └── requireTokenAuth.js       # Shared header token (limited use)
    └── scripts/                      # Installed into <project>/scripts/ by --scripts
        ├── _lib.sh                   # Shared helpers (.env, stack outputs)
        ├── deploy.sh                 # Content-only default; --infra for stacks
        ├── lint.sh                   # cfn-lint + validate-template
        ├── privacy-check.sh          # Fail-closed leak scan before every push
        ├── setup-params.sh           # SSM String/SecureString at a hidden prompt
        ├── create-user.sh            # Cognito admin-create-user
        ├── get-urls.sh               # Print every stack output
        ├── logs.sh                   # Tail a Lambda's logs
        ├── dev.sh                    # Serve staging/ locally
        ├── make-icons.sh, make-ico.py    # Favicon / PWA icon set from favicon.svg
        └── screenshots.sh, cdp-shot.mjs  # Desktop + mobile screenshots
```

The repo stores steering under `kiro/steering` (no dot) so it shows up on GitHub;
the installer copies it to `.kiro/steering` in your project.

## Install into a project

```bash
# Steering only, into the current directory
curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh | bash

# Everything (steering + templates + scripts + README) into a specific project
curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh \
  | bash -s -- ./my-new-project --all

# Or from a local clone
./install.sh ../my-new-project --all
```

Options: `--templates`, `--scripts`, `--readme`, `--all`, `--force`. The
installer is safe by default: existing files are **skipped**; `--force`
overwrites after saving a `.bak-<timestamp>` copy. It prints the version it
installed and writes `.kiro/.standards-version` into the project.

Environment overrides: `STANDARDS_REPO` (URL or local path) and `STANDARDS_REF`
(branch or tag; `STANDARDS_BRANCH` still works as a deprecated alias).

After installing: open the project in Kiro, then replace the `{{PLACEHOLDERS}}`.
With `--scripts`, copy `.env.example` to `.env` and copy the stacks you need from
`templates/` into `infra/`.

## Versions

- **`main` is always the latest version** (currently v2). Plain installs pull it.
- Older versions stay available as branches and tags: branch `v1`, tag `v1.0.0`.
- Install v1: `STANDARDS_REF=v1 ./install.sh ../my-project` (or with the curl
  one-liner: `curl ... | STANDARDS_REF=v1 bash`).
- Releases are tagged (`v2.0.0`, ...). See `CHANGELOG.md`.

## Project shapes in plain English

- **A. Static site + separate API (the standard).** The browser downloads the
  site from CloudFront (fast, cached, almost free); the pages call a separate
  API (API Gateway + Lambda) for data. UI and API deploy independently.
- **A0. Static-only public site.** The same site with no API at all: S3 +
  CloudFront only. The cheapest shape; no auth needed.
- **B. One function does everything (exception).** A single Lambda Web Function
  serves both the pages and the API. One thing to deploy, but no CDN unless you
  add CloudFront, every UI change redeploys the function, and at the time of
  writing it isn't available in London. Only when the owner asks for it.

## Who needs to sign in?

| Site / API | Auth |
|---|---|
| Public, read-only, non-sensitive | None (still throttled; posture stated) |
| Private/personal data, or any admin/write function | Amazon Cognito |
| Machine-to-machine, or public endpoints needing per-client throttling | API Gateway API key |
| Trivial, non-sensitive internal tool | Shared header token |

Details in `kiro/steering/security-standards.md`.

## Cost principle

An app nobody uses should cost close to nothing: **under $1/month idle** (the
shared Route53 zone excluded). NAT gateways, VPC endpoints, WAF, Secrets Manager,
customer-managed KMS keys, provisioned capacity and always-on databases need
explicit approval. Every design states an idle and a busy-month estimate. See
`kiro/steering/cost-standards.md`.

## Conventions at a glance

- Region `eu-west-2` (London); ACM certs for CloudFront in `us-east-1`.
- Runtimes: the latest Lambda-supported Node.js runtime for APIs and the latest
  supported Python runtime for jobs. Check AWS's supported-runtimes list at
  project start; never ship a deprecated runtime.
- IaC: raw CloudFormation, linted before every deploy.
- Data: one DynamoDB on-demand table per app, retained.
- Config and secrets: SSM Parameter Store under `/<project>/...`; secrets entered
  by the user at a hidden prompt.
- Deploy only through `scripts/deploy.sh`; `staging/` is the live site.
- Repos private by default; privacy check before every push.

## Also worth doing: make this a GitHub template repo

Mark the repo as a *template repository* in its GitHub settings for a one-click
**Use this template** on brand-new projects. The installer is still the better
route for adding or updating standards in existing projects.
