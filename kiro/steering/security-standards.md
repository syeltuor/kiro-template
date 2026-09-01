# Security Standards

Applies to every project. Security choices should be explicit, never accidental.

## Secrets: never in the repo

- No API keys, tokens, passwords, or connection strings committed to git. This
  includes markdown docs and READMEs.
- Source secrets from CloudFormation outputs, SSM Parameter Store, or environment
  variables injected at deploy time.
- Provide a `.env.example` with key names and empty values; keep the real `.env`
  gitignored.
- If a secret is ever committed, treat it as compromised: rotate it, don't just
  delete the line.

## Public read, protected write

- Read-only, non-sensitive endpoints can be public.
- Anything that creates, updates, or deletes, plus all admin surfaces, must be
  authenticated.

## Authentication: two supported options

Pick one per project. **API Gateway API Key is the canonical/default choice**;
the header token is a lightweight alternative for small internal apps.

### Option 1 — API Gateway API Key (canonical)

- Define an API Key + Usage Plan in the API Gateway stack. Protected methods set
  `ApiKeyRequired: true`.
- Clients send the key in the `x-api-key` header.
- The key value comes from the stack, never hardcoded. Retrieve it via
  `aws apigateway get-api-key --include-value` or a stack output.
- The Usage Plan doubles as rate limiting (see below).
- Frontend admin pages: prompt for the key, store in `localStorage`, and support
  bootstrapping via `?key=` / `?apikey=` in the URL, then strip it from the URL.
- Rotate keys periodically. Rotation = regenerate in API Gateway, update clients.

See `templates/auth/requireApiKeyAuth.md`.

### Option 2 — Shared header token (lightweight)

- A single shared secret stored in the Lambda's `ADMIN_TOKEN` env var.
- Clients send it in a custom header (e.g. `X-Admin-Token`); the handler compares
  and returns 401 on mismatch, 500 if the env var is missing.
- Frontend: same `localStorage` + `?token=` bootstrap pattern.
- Cheaper and simpler, but: single shared secret, no per-client keys, no built-in
  usage plan. Acceptable only for small internal/family apps.

See `templates/auth/requireTokenAuth.js`.

### For anything higher-stakes

Step up to Amazon Cognito, JWTs with expiry, and role-based access. Note the
upgrade path in the project README rather than stretching a shared secret.

## Rate limiting / throttling

Every public API gets request throttling. Don't ship an unthrottled public
endpoint.

- **API Gateway Usage Plan** (pairs naturally with API Key auth). Typical small
  API: burst 100, rate 50 req/s.
- **`serverless-api-gateway-throttling` plugin** for Serverless Framework apps
  without API keys (stage-level throttling; the built-in `usagePlan.throttle`
  only applies to keyed requests). Typical low-traffic app: 10 req/s, burst 50.
- For strict cost control or abuse protection, add AWS WAF rate-based rules.

## Transport and CORS

- HTTPS everywhere; TLS 1.2 minimum (enforced at CloudFront and custom domains).
- CORS `origin` restricted to the app's own domain, not `*`. Only allow the
  headers actually used (e.g. `Content-Type`, `x-api-key` or `X-Admin-Token`).

## IAM

- Least privilege. Scope Lambda roles to specific actions on specific resource
  ARNs. Never `Resource: "*"` for data access.

## When creating a network-exposed endpoint

Always state the auth posture. If an endpoint is intentionally public, say so and
confirm it's read-only. Never silently create an unauthenticated write endpoint.
