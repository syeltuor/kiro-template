---
inclusion: auto
name: cognito
description: Amazon Cognito user pool setup and user authentication for a site or API - login, sign-in, sign-up, managed login and branding, branding error page, componentClasses, PKCE, JWT tokens, Cognito authorizer, callback URLs, redirect_mismatch, MFA, create user, domain prefix, protect a site behind auth. Use when adding or debugging Cognito or user auth.
---
<!-- kiro-template v2.0.0 -->

# Cognito Standard Configuration

Only for auth row (b) in `security-standards.md`. Template:
`templates/cognito-stack.yaml` (read its pre-create checklist first).

## User pool and client

- **No self sign-up**: `AllowAdminCreateUserOnly: true`. Users via
  `templates/scripts/create-user.sh` (`admin-create-user`, emailed temporary
  password). Recovery by verified email.
- **MFA is the owner's call**: off is fine for a single-user read-only dashboard;
  on for anything that changes data or moves money.
- **Essentials** plan (needed for managed login v2; free up to 10,000 MAU at time
  of writing). **Never Plus** (no free tier). Verify pricing.
- **Authorization-code flow with PKCE**, **public client** (no secret), scopes
  `openid email profile`.
- Callback and logout URLs pinned to `https://{{DOMAIN}}/`, nothing else.

## API protection

- **Cognito User Pools authorizer on every non-public route.** Only OPTIONS
  preflights are unauthenticated (MOCK integration, CORS headers only). The Lambda
  also checks the claims it relies on.
- CORS headers allowed: only `Content-Type` and `Authorization`.

## Token storage tradeoff

Static site: ID/access tokens in `sessionStorage`, refresh in `localStorage` if
the user stays signed in. XSS could read them, so: strict CSP (`script-src
'self'`, no inline or third-party JS), never put API data into `innerHTML`, revoke
on sign-out. Higher stakes: a **backend-for-frontend** holding tokens in an
`HttpOnly` cookie; note the upgrade path in the README.

CSP `connect-src` and `form-action` must include the managed login origin.

## Managed login (v2) branding

- With `ManagedLoginVersion: 2`, a client **without a branding style shows an
  error page**. Create an `AWS::Cognito::ManagedLoginBranding` per client,
  `DependsOn` the `UserPoolDomain`.
- `UseCognitoProvidedValues: false` when supplying `Settings`. `Settings` is
  **partial** (merged with defaults): set only what you change.
- Strict schema: `link` and `input` are top-level **`componentClasses`**, not
  `components` (else `$.components.link UnknownProperty` and rollback).
- **Discover the real schema**: temporary client with
  `UseCognitoProvidedValues: true`, then `aws cognito-idp
  describe-managed-login-branding-by-client --user-pool-id <id> --client-id <id>
  --return-merged-resources`; copy the key paths.
- Branding colours (`RRGGBBAA` hex) are stack parameters.
- Domain prefix is **globally unique per region**: check it's free first.
- **Test with curl**: authorize URL with a real S256 PKCE challenge, `curl -sL`,
  ends on the sign-in page with the expected `<title>`; an unregistered
  `redirect_uri` gives `redirect_mismatch`.
