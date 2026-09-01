# AWS Serverless Project Standards

A copy-ready starter kit that captures the conventions used across Outback Projects
serverless web apps (e.g. Family Agenda, Swimming Times). Drop these into a new
project to give Kiro the right context and to keep architecture, security, and
deployment consistent.

## What's in here

```
standards/
├── README.md                     # This file
├── PROJECT-README-TEMPLATE.md    # Generic README to copy into a new project
├── .kiro/
│   └── steering/                 # Kiro steering files (guidance for the agent)
│       ├── tech-standards.md         # Core architecture + conventions (always on)
│       ├── frontend-hosting.md       # S3 + CloudFront static hosting (always on)
│       ├── security-standards.md     # Auth, secrets, CORS, TLS (always on)
│       └── deployment-standards.md   # Deploy scripts, infra, favicons (on demand)
└── templates/                    # Reusable infra you'd otherwise rewrite
    ├── certificate-stack.yaml        # ACM cert (us-east-1) for CloudFront
    ├── cloudfront-stack.yaml         # CloudFront + S3 (OAC) + Route53
    ├── deploy-cloudfront.sh          # Orchestrates cert -> CloudFront deploy
    ├── deploy-api.sh                 # Generic API stack deploy script
    └── auth/
        ├── requireApiKeyAuth.md      # API Gateway API Key auth (canonical)
        └── requireTokenAuth.js       # Header-token auth (lightweight option)
```

## How to use it in a new project

### Quick: the install script (recommended)

Once this repo is on GitHub, set the repo URL in `install.sh` (replace
`{{GH_USER}}/{{REPO}}` in the `DEFAULT_REPO` line), then from any project run:

```bash
# Steering files only, into the current directory
curl -fsSL https://raw.githubusercontent.com/{{GH_USER}}/{{REPO}}/main/install.sh | bash

# Everything (steering + templates + README), into a specific project
curl -fsSL https://raw.githubusercontent.com/{{GH_USER}}/{{REPO}}/main/install.sh \
  | bash -s -- ./my-new-project --all
```

Or clone the repo and run it locally: `./install.sh ../my-new-project --all`.

The script is safe by default: existing files are **skipped** (or backed up to
`.bak-<timestamp>` when you pass `--force`), never silently overwritten. Options:
`--templates`, `--readme`, `--all`, `--force`. You can also point it at a
different repo/branch with the `STANDARDS_REPO` and `STANDARDS_BRANCH` env vars.

After installing: open the project in Kiro (steering loads automatically), then
replace the `{{PLACEHOLDERS}}` in any README/templates you copied.

### Manual (no script)

1. Copy the `.kiro/` folder into the root of your new project.
2. Copy `PROJECT-README-TEMPLATE.md` to `README.md` and replace the placeholders.
3. Copy whatever you need from `templates/` and replace the placeholder values.
4. Delete the pieces you don't need (e.g. drop `deploy-cloudfront.sh` if the app
   embeds its frontend in Lambda instead of using S3 + CloudFront).

### Also worth doing: make the repo a GitHub template

Mark the repo as a *template repository* in its GitHub settings. That gives you a
one-click **Use this template** for brand-new projects. The install script is
still the better route for adding standards to **existing** projects or pulling in
updates later, so keep both.

## The two reference architectures

These standards support two shapes. Pick per project.

**A. CloudFront + S3 static UI + separate API (default, from Swimming Times)**
Best when the frontend is more than a page or two, needs a CDN, or the API and UI
evolve independently. Raw CloudFormation stacks, static site in S3 behind
CloudFront (OAC), APIs as separate Lambda + API Gateway stacks.

**B. Embedded frontend in Lambda (lightweight, from Family Agenda)**
Best for tiny internal/family apps. Serverless Framework, HTML embedded into a
single Lambda that also serves the API. Simpler, cheaper, fewer moving parts.

The steering files describe both and mark A as the default.

## Conventions at a glance

- Region: `eu-west-2` (London). ACM certs for CloudFront live in `us-east-1`.
- Runtimes: Node.js 20.x (APIs), Python 3.12 (scrapers/jobs).
- Data: DynamoDB, on-demand (`PAY_PER_REQUEST`) billing.
- Auth: two documented options, API Gateway API Key (canonical) or a shared
  header token (lightweight). Public read, protected write.
- Secrets never live in the repo. Pull them from CloudFormation outputs or SSM.
- Custom domains via Route53 + ACM, HTTPS enforced, TLS 1.2 minimum.
- Target cost for small apps: a few dollars a month.
