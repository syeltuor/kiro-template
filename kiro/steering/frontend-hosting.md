---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Frontend Hosting Standards

How to host the web frontend. The standard is a private S3 bucket behind
CloudFront (shapes A and A0 in `tech-standards.md`). The single Web Function shape
(B) is an exception.

## Standard: S3 + CloudFront + OAC

Static site (HTML/CSS/JS) lives in a **private** S3 bucket, served through a
CloudFront distribution. The bucket is never public; CloudFront reaches it via
Origin Access Control. Template: `templates/cloudfront-stack.yaml`.

### Required CloudFront configuration

- **Origin Access Control (OAC)**, not the legacy Origin Access Identity. The bucket
  policy grants `s3:GetObject` only to the CloudFront service principal, scoped by
  `AWS:SourceArn` to the specific distribution, and denies non-TLS access.
- Bucket: public access block on, `BucketOwnerEnforced`, SSE-S3 (no KMS cost),
  retained on stack delete.
- **HTTPS enforced**: `ViewerProtocolPolicy: redirect-to-https`.
- **TLS**: `MinimumProtocolVersion: TLSv1.2_2021`, `SslSupportMethod: sni-only`.
- **Custom domain** via `Aliases`, backed by an ACM cert in `us-east-1`.
- **Price class**: `PriceClass_100` (North America + Europe).
- **HTTP/2 + IPv6** enabled. **Compression** on.
- **SPA-style error routing**: 403 and 404 map to `/index.html` with 200.
- **Caching**: AWS managed cache policy `CachingOptimized`.

### Security headers

Attach a **CloudFront response headers policy** (in the template) with:

- HSTS (2 years), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
  `Referrer-Policy: strict-origin-when-cross-origin`.
- A **strict Content-Security-Policy**, passed in as a parameter. Baseline:
  `default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;
  connect-src 'self' <api-origin> <cognito-origin>; form-action 'self'
  <cognito-origin>; frame-ancestors 'none'; base-uri 'self'; object-src 'none'`.
- That means **no inline scripts or styles** and no third-party JS. Build the UI
  with that in mind from day one (no `style=` attributes, no `onclick=`).

### Cache-Control

Objects are uploaded with
`Cache-Control: public, max-age=0, s-maxage=86400, must-revalidate` and every
deploy invalidates `/*`. Browsers revalidate, CloudFront serves from cache, and a
deploy is visible in 1-3 minutes. Stale UI after deploy = missing invalidation or
missing Cache-Control.

### DNS

Route53 alias records, both **A and AAAA**, pointing at the distribution
(CloudFront hosted zone `Z2FDTNDATAQYW2`). Reuse the existing hosted zone for the
parent domain; don't create a new zone per app.

### Deploy

`staging/` is the live site, synced as-is by the project's deploy script. See
`deployment-standards.md` for the sync rules, the content-only vs `--infra`
modes and the post-deploy checks.

## Variants

- **Static-only public site (A0)**: the same stack with no API and no Cognito.
  Leave the API/Cognito origins out of the CSP (`connect-src 'self'`). No auth,
  state "intentionally public" in the README.
- **Authenticated site (A + Cognito)**: the Cognito callback and logout URLs are
  exactly `https://<domain>/`. The CSP `connect-src` and `form-action` must include
  the Cognito managed login origin, and `connect-src` the API origin. The deploy
  script writes the client ID and Cognito URL into a generated `config.js`.

## PWA and favicons

Every frontend ships a complete icon set and a web manifest:

- `favicon.ico`, `favicon.svg`
- PNG sizes (16, 32, 48, 96, 128, 192, 512) plus `apple-touch-icon.png` (180)
- `manifest.json` (not `.webmanifest`, so S3 serves `application/json`) with name,
  icons, theme colour, display mode

Generate them from `favicon.svg` with `templates/scripts/make-icons.sh`.

## Exception: single Web Function (shape B)

Only when the owner asks for it. One Lambda Web Function serves pages and API;
no S3. Put CloudFront in front for the custom domain, TLS policy, security headers
and caching of static assets. See `tech-standards.md` for the region, runtime,
endpoint-access and cost caveats.
