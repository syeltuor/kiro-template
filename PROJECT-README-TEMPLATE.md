<!-- kiro-template v2.0.0 -->
<!--
  README template for a serverless AWS project (Kiro AWS Serverless Standards v2).
  Copy to your project root as README.md and replace all {{PLACEHOLDERS}}.
  Delete sections that don't apply (e.g. no API, no auth, no scheduled jobs).
  Never put secrets, account IDs or personal identifiers in this file.
-->

# {{PROJECT_NAME}}

{{ONE_LINE_DESCRIPTION}}

## Features

- {{FEATURE_1}}
- {{FEATURE_2}}
- {{FEATURE_3}}

## Architecture

Shape: **{{A_STATIC_PLUS_API | A0_STATIC_ONLY | B_WEB_FUNCTION_EXCEPTION}}**
(A is the standard. B is an exception used only when the owner asked for it;
if chosen, record why and the approved region here.)

```
Browser ──HTTPS──▶ CloudFront ──OAC──▶ S3 (staging/ = the site)
   │
   └──▶ API Gateway (Cognito authorizer, throttled) ──▶ Lambda ──▶ DynamoDB
                                                       Scheduler ──▶ Lambda (jobs)
```

| Piece | What it is |
|---|---|
| Site | Static HTML/CSS/JS in `staging/`, private S3 bucket behind CloudFront (OAC, HTTPS, CSP) at `https://{{DOMAIN}}` |
| API | API Gateway REST → `{{project}}-api` Lambda (Node.js, latest Lambda-supported runtime) |
| Jobs | `{{project}}-{{job}}` Lambda (Python, latest supported runtime), EventBridge Scheduler `{{SCHEDULE}}` ({{TIMEZONE}}) |
| Data | DynamoDB table `{{TABLE_NAME}}`, on-demand, retained |
| Auth | {{COGNITO_OR_NONE}} |
| Config | SSM Parameter Store under `/{{project}}/` |
| Region | {{REGION}} (certificate in us-east-1) |

Stacks (raw CloudFormation in `infra/`, outputs exported as `<stack>-<OutputKey>`):

| Stack | Template | Region |
|---|---|---|
| `{{project}}-certificate` | `infra/certificate-stack.yaml` | us-east-1 |
| `{{project}}-artifacts` | `infra/artifacts-stack.yaml` | {{REGION}} |
| `{{project}}-data` | `infra/data-stack.yaml` | {{REGION}} |
| `{{project}}-auth` | `infra/cognito-stack.yaml` | {{REGION}} |
| `{{project}}-api` | `infra/api-stack.yaml` (packaged) | {{REGION}} |
| `{{project}}-cloudfront` | `infra/cloudfront-stack.yaml` | {{REGION}} |

## Prerequisites

- AWS CLI v2 with credentials for the target account
- A Route53 hosted zone for `{{PARENT_DOMAIN}}` (reused, not created per app)
- Node.js and Python for local scripts and tests (current versions)
- Google Chrome, only for screenshots and icon generation

## Setup (first time)

1. `cp .env.example .env` and fill it in (`.env` is gitignored).
2. `npm run deploy:infra` (lints, deploys the stacks in order, syncs the site).
   The certificate waits for DNS validation (2-5 min); a new distribution takes
   5-15 min.
3. **You** set the secrets at a hidden prompt (never paste them anywhere):
   `scripts/setup-params.sh secure {{name}}`
4. **You** create your login (if Cognito): `npm run create-user -- <email>`
   (Cognito emails a temporary password; check spam).
5. {{FIRST_DATA_LOAD, e.g. npm run backfill}}

## Deploy

| Command | What it does |
|---|---|
| `npm run deploy` | Content only: sync `staging/` to S3, invalidate CloudFront (1-3 min) |
| `npm run deploy:infra` | Lint + deploy all stacks, then the content phase |
| `npm run deploy:app` / `deploy:prod` | Same as `deploy` (single stage: `prod` is an alias) |
| `npm run logs` | Tail the API Lambda logs |
| `npm run get-urls` | Print the live URLs and IDs from stack outputs |
| `npm run lint` | cfn-lint + validate-template |
| `npm test` | Unit tests |

Always deploy through the script. `staging/` **is** the site: whatever is in it
gets published (old mock-ups go in `ARCHIVE/`).

## Authentication

Posture: **{{ONE_OF_BELOW}}**

- *None*: "This site is intentionally public and read-only. The API (if any) is
  throttled at {{RATE}} req/s, burst {{BURST}}."
- *Cognito*: "Every API route requires a Cognito ID token (User Pools authorizer).
  Users are created by an admin (no self sign-up). MFA: {{ON_OR_OFF_AND_WHY}}.
  Sign-in uses the authorization-code flow with PKCE on a public client. Tokens
  are kept in browser storage, mitigated by a strict CSP. Upgrade path: a
  backend-for-frontend with HttpOnly cookies."

## API endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `{{BASE_URL}}/{{resource}}` | {{Cognito \| public}} | {{description}} |

## Security

- Secrets and personal identifiers live only in SSM (`SecureString` / `String`),
  set by the user at a hidden prompt. None are in git, logs, tests or docs.
- HTTPS only, TLS 1.2 minimum, HSTS, strict CSP. CORS allows only
  `https://{{DOMAIN}}` with `Content-Type,Authorization`.
- Least-privilege IAM: one role per Lambda, scoped to the table, its own log
  group and the `/{{project}}/...` parameters it reads.
- `scripts/privacy-check.sh` runs before every push and fails closed.
- If a secret is ever committed, rotate it.

## Configuration (what lives in SSM)

| Parameter | Type | Set by | Purpose |
|---|---|---|---|
| `/{{project}}/{{name}}` | SecureString | user (hidden prompt) | {{purpose}} |
| `/{{project}}/{{name}}` | String | `scripts/setup-params.sh` | {{purpose}} |

## Data sources and limits

| Source | What we use | Limits / quirks (verified live, see `.agents/{{project}}/api-verification.md`) |
|---|---|---|
| {{SOURCE}} | {{ENDPOINTS}} | {{e.g. data lags a day, max 31 days per request, rate limit}} |

The UI shows "data up to {{time}}" so upstream lag doesn't look like a bug.

## Cost (idle vs busy month)

| Service | Idle month | Busy month ({{assumption}}) |
|---|---|---|
| CloudFront | {{$}} | {{$}} |
| S3 | {{$}} | {{$}} |
| API Gateway | {{$}} | {{$}} |
| Lambda | {{$}} | {{$}} |
| DynamoDB on-demand | {{$}} | {{$}} |
| CloudWatch Logs ({{14-30}}-day retention) | {{$}} | {{$}} |
| Cognito Essentials | {{$}} | {{$}} |
| **Total** | **{{< $1}}** | **{{$}}** |

Real bill after the first week: **{{ACTUAL}}** (Cost Explorer, tag
`Project={{project}}`). Not used, on purpose: NAT gateway, VPC endpoints, WAF,
Secrets Manager, customer-managed KMS keys, provisioned capacity.

## Troubleshooting

- **Stale UI after deploy**: the invalidation takes 1-3 minutes.
- **"CORS error" in the browser**: check the status code. 403 on the preflight
  = route not deployed (bump `ApiDeploymentV<n>`); 502 = Lambda crashed or timed
  out (`npm run logs`); 401 = missing/expired token.
- **Login page shows an error**: the app client has no managed login branding.

## Standards

Built to the Kiro AWS Serverless Standards (see `.kiro/.standards-version`).
