---
inclusion: auto
name: frontend-hosting
description: Static site and frontend hosting on S3 + CloudFront with OAC - website UI, HTML/CSS/JS, styling, SPA routing, custom domain, Route53 alias A/AAAA, TLS, security headers, Content-Security-Policy (CSP), inline scripts or styles, Cache-Control, cache invalidation, stale UI, favicon and PWA manifest icons. Use when building, styling or hosting a web frontend.
---
<!-- kiro-template v2.0.0 -->

# Frontend Hosting Standards

Shapes A and A0: private S3 bucket behind CloudFront. Template:
`templates/cloudfront-stack.yaml`.

## CloudFront and bucket

- **Origin Access Control (OAC)**, not legacy OAI. Bucket policy: `s3:GetObject`
  only for the CloudFront service principal, `AWS:SourceArn` = this distribution;
  deny non-TLS.
- Bucket: public access block, `BucketOwnerEnforced`, SSE-S3 (no KMS cost),
  retained on delete.
- `ViewerProtocolPolicy: redirect-to-https`; `MinimumProtocolVersion:
  TLSv1.2_2021`, `SslSupportMethod: sni-only`.
- `Aliases` custom domain, ACM cert in `us-east-1`.
- `PriceClass_100`, HTTP/2 + IPv6, compression, managed `CachingOptimized` policy.
- SPA routing: 403 and 404 -> `/index.html` with 200.

## Security headers

CloudFront response headers policy:

- HSTS (2 years), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
  `Referrer-Policy: strict-origin-when-cross-origin`.
- **Strict CSP** as a parameter. Baseline: `default-src 'self'; script-src
  'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' <api-origin>
  <cognito-origin>; form-action 'self' <cognito-origin>; frame-ancestors 'none';
  base-uri 'self'; object-src 'none'`.
- So **no inline scripts or styles**, no third-party JS: no `style=` or
  `onclick=` attributes, from day one.

## DNS and deploy

- Route53 alias **A and AAAA** to the distribution (CloudFront hosted zone
  `Z2FDTNDATAQYW2`), in the existing parent-domain zone; no new zone per app.
- `staging/` is the live site; sync, Cache-Control and invalidation rules:
  `deployment-standards.md`.

## Variants

- **A0 (static-only public)**: no API or Cognito; CSP `connect-src 'self'`; state
  "intentionally public" in the README.
- **A + Cognito**: the deploy script writes the client ID and Cognito URL into a
  generated `config.js`; CSP includes the API and managed login origins
  (`cognito.md`).
- **B (Web Function, owner asks only)**: CloudFront in front for domain, TLS,
  headers and asset caching (`web-functions.md`).

## PWA and favicons

- `favicon.ico`, `favicon.svg`, PNGs (16, 32, 48, 96, 128, 192, 512),
  `apple-touch-icon.png` (180).
- `manifest.json` (not `.webmanifest`, so S3 serves `application/json`): name,
  icons, theme colour, display mode.
- Generate from `favicon.svg`: `templates/scripts/make-icons.sh`.
