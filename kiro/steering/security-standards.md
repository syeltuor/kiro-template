---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Security Standards

## Never in git

- Never in git (code, notes, fixtures, commit messages): secrets, tokens,
  passwords, connection strings, account numbers, meter/device IDs, addresses,
  postcodes, coordinates. Personal identifiers are secrets: SSM, never logs. Use
  neutral example values.
- Run the fail-closed privacy check (`scripts/privacy-check.sh`) before every push.
- `.env.example` with empty values; the real `.env` is gitignored.
- A committed secret is compromised: rotate it, don't just delete it.

## Secrets and config: SSM Parameter Store

- Standard tier under `/<project>/...`: `String` for config, `SecureString`
  (`alias/aws/ssm`) for secrets. No Secrets Manager or customer-managed KMS key
  without cost approval.
- **The user enters secrets** at a hidden `read -rs` prompt, never in chat or as
  arguments (`templates/scripts/setup-params.sh` prints the commands).
- **Agents only check existence** (`aws ssm get-parameters --names ...
  --query 'InvalidParameters'`); never decrypt or print a value.

## Auth decision table

Private/personal data, writes and admin need auth; many sites need **none**.
State the row for every endpoint in the design and README. Never silently create
an unauthenticated write endpoint.

| Site / API | Auth | Notes |
|---|---|---|
| (a) Public, read-only, non-sensitive | **None** | Throttled; say "intentionally public, read-only". Static-only: no Cognito/API Gateway |
| (b) Private/personal data, or any admin/write | **Cognito** (default) | Managed login + Cognito authorizer on every non-public route (`cognito.md`) |
| (c) Machine-to-machine, or per-client usage-plan throttling | **API Gateway API key** | Meters callers; not user auth (`templates/auth/requireApiKeyAuth.md`) |
| (d) Trivial, non-sensitive internal tool | Shared header token | Never for personal data or money (`templates/auth/requireTokenAuth.js`) |

More users or roles: stay on Cognito, add groups.

## Throttling, transport, CORS, IAM

- Every public API throttled at the stage (`MethodSettings`), typically 10 req/s,
  burst 50. Usage plans only throttle keyed requests (row c). WAF only with
  approval.
- TLS: CloudFront `TLSv1.2_2021`, API Gateway `SecurityPolicy_TLS13_1_2_2021_06`.
- CORS origin = the app's domain, never `*`; only headers actually used. Add CORS
  headers to `DEFAULT_4XX`/`DEFAULT_5XX` gateway responses.
- IAM: a role per function, specific actions on specific ARNs, never `dynamodb:*`
  or `Resource: "*"` for data. SSM reads: `parameter/<project>/*` plus
  `kms:Decrypt` with a `kms:ViaService` condition.
