---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Security Standards

Applies to every project. Security choices should be explicit, never accidental.

## Secrets: never in the repo

- No API keys, tokens, passwords, or connection strings committed to git. This
  includes markdown docs, READMEs and design notes.
- Secrets and config come from **SSM Parameter Store** (see below), CloudFormation
  outputs, or environment variables injected at deploy time.
- Provide a `.env.example` with key names and empty values; keep the real `.env`
  gitignored.
- If a secret is ever committed, treat it as compromised: rotate it, don't just
  delete the line.

## Public read, protected write

- Read-only, non-sensitive endpoints and pages can be public.
- Anything that creates, updates, or deletes, plus all admin surfaces and anything
  that shows private or personal data, must be authenticated.

## Which auth? Decision table

Many sites need **no user auth at all**. Pick the row that fits; state the
posture in the design and the README.

| Site / API | Auth | Notes |
|---|---|---|
| (a) Public, read-only, non-sensitive | **None** | Still throttled. Say "intentionally public, read-only" in the design. A static-only public site is just S3 + CloudFront: no Cognito, no API Gateway, no authorizer |
| (b) Shows private/personal data, or has any admin/write function | **Amazon Cognito** (default) | User pool + managed login + Cognito authorizer on every non-public route (config below) |
| (c) Machine-to-machine, or a public endpoint that needs per-client usage-plan throttling | **API Gateway API key** | Keys identify callers and meter them; they are not user authentication. See `templates/auth/requireApiKeyAuth.md` |
| (d) Trivial, non-sensitive internal tool | Shared header token (allowed) | Never for personal data or money. See `templates/auth/requireTokenAuth.js` |

When the needs grow (more users, roles), stay on Cognito and add groups and
role checks rather than stretching an API key or a shared token.

## Cognito standard configuration

Use it only when the decision table says (b). Template:
`templates/cognito-stack.yaml`.

- **No self sign-up** for single-user / small-group apps:
  `AllowAdminCreateUserOnly: true`. Users are created with `admin-create-user`
  (`templates/scripts/create-user.sh`); Cognito emails a temporary password.
  Recovery by verified email.
- **MFA is the owner's call.** Off is acceptable for a single-user read-only
  dashboard; turn it on for anything that changes data or moves money.
- **Feature plan: Essentials** (needed for managed login v2; free up to 10,000
  MAU at the time of writing). **Never Plus** (no free tier). Verify the pricing.
- **Authorization-code flow with PKCE** on a **public client** (no client secret).
  Scopes `openid email profile`.
- **Callback and logout URLs pinned** to the app origin (e.g.
  `https://{{DOMAIN}}/`). Nothing else.
- **Cognito User Pools authorizer on every non-public API route.** OPTIONS
  preflights are the only unauthenticated methods, and they return CORS headers
  only (MOCK integration, no data). The Lambda also checks the claims it relies on.
- **CORS**: only the app origin; only `Content-Type` and `Authorization` headers.
- **Stage throttling always** (e.g. 10 req/s, burst 50 for a small app).
- **Token storage tradeoff.** A pure static site keeps tokens in browser storage
  (ID/access in `sessionStorage`, refresh in `localStorage` if the user should stay
  signed in). XSS could read them, so ship a **strict CSP** via the CloudFront
  response headers policy (`script-src 'self'`, no inline script, no third-party
  JS), never put API data into `innerHTML`, revoke on sign-out. Upgrade path for
  anything higher-stakes: a **backend-for-frontend** that holds tokens in an
  `HttpOnly` cookie. Note it in the README.
- Managed login branding has sharp edges; read `lessons-learned.md` and the
  comments in `templates/cognito-stack.yaml` before creating the pool.

## Secrets and config: SSM Parameter Store

- **Standard tier** parameters: `String` for config, `SecureString` for secrets
  with the **AWS-managed key** (`alias/aws/ssm`). Not Secrets Manager, not a
  customer-managed KMS key, unless the owner approves the cost (see
  `cost-standards.md`).
- Namespace everything under `/<project>/...` (e.g. `/myapp/upstream/api-key`).
- **The user sets secrets themselves** at a hidden prompt (`read -rs`), never
  pasted into chat, never passed as command-line arguments (they land in shell
  history and process lists). `templates/scripts/setup-params.sh` prints the exact
  commands.
- **Agents only check existence** (`aws ssm get-parameters --names ...
  --query 'InvalidParameters'`). Never decrypt or print a secret value.
- **Personal identifiers are secrets too**: meter/device IDs, account numbers,
  home addresses, postcodes, coordinates. Keep them in SSM, out of git, out of logs.
- Use **neutral example values** in tests, fixtures and docs (e.g. a well-known
  public landmark address, `example.com`).
- Least-privilege IAM per function, scoped to the specific
  `arn:aws:ssm:<region>:<account>:parameter/<project>/...` ARNs it reads, plus
  `kms:Decrypt` on the AWS-managed SSM key with a `kms:ViaService` condition.

## Rate limiting / throttling

Every public API gets request throttling. Don't ship an unthrottled endpoint.

- **Stage-level throttling** (`MethodSettings` on the API Gateway stage) applies to
  every request. Typical small app: 10 req/s, burst 50.
- **Usage plans** only throttle keyed requests; use them with API keys (row c).
- AWS WAF rate rules only with approval (fixed monthly cost; see
  `cost-standards.md`).

## Transport and CORS

- HTTPS everywhere; TLS 1.2 minimum (CloudFront `TLSv1.2_2021`, API Gateway
  `SecurityPolicy_TLS13_1_2_2021_06`).
- CORS `origin` restricted to the app's own domain, never `*`. Allow only the
  headers actually used. Add CORS headers to API Gateway `DEFAULT_4XX` /
  `DEFAULT_5XX` gateway responses so the browser can read 401/403/429/5xx.

## IAM

- Least privilege. Scope Lambda roles to specific actions on specific resource
  ARNs. Never `Resource: "*"` for data access.

## When creating a network-exposed endpoint

Always state the auth posture (which row of the decision table). If an endpoint is
intentionally public, say so and confirm it's read-only. Never silently create an
unauthenticated write endpoint.

## Limited-use options (rows c and d)

### API Gateway API key

- API Key + Usage Plan in the API stack; protected methods set
  `ApiKeyRequired: true`; clients send `x-api-key`.
- The key value comes from the stack, never hardcoded
  (`aws apigateway get-api-key --include-value`).
- Rotate periodically: regenerate in API Gateway, update clients.

### Shared header token

- One shared secret in the Lambda's `ADMIN_TOKEN` env var (sourced from SSM at
  deploy time). Clients send `X-Admin-Token`; 401 on mismatch, 500 if unset.
- Single shared secret, no per-client keys, no usage plan. Only for trivial
  non-sensitive internal tools, never for personal data.
