# Frontend Hosting Standards

How to host the web frontend. The default is S3 + CloudFront; the embedded-Lambda
approach is a documented fallback for tiny apps.

## Default: S3 + CloudFront + OAC

Static site (HTML/CSS/JS) lives in a **private** S3 bucket, served through a
CloudFront distribution. The bucket is never public; CloudFront reaches it via
Origin Access Control.

### Required CloudFront configuration

- **Origin Access Control (OAC)**, not the legacy Origin Access Identity. The S3
  bucket policy grants `s3:GetObject` only to the CloudFront service principal,
  scoped by `AWS:SourceArn` to the specific distribution.
- **HTTPS enforced**: `ViewerProtocolPolicy: redirect-to-https`.
- **TLS**: `MinimumProtocolVersion: TLSv1.2_2021`, `SslSupportMethod: sni-only`.
- **Custom domain** via `Aliases`, backed by an ACM cert in `us-east-1`.
- **Price class**: `PriceClass_100` (North America + Europe) unless there's a
  reason to serve other regions.
- **HTTP/2 + IPv6** enabled.
- **Compression** enabled (`Compress: true`).
- **SPA-style error routing**: map 403 and 404 to `/index.html` with response
  code 200 so client-side routing works.
- **Caching**: use an AWS managed cache policy (e.g. CachingOptimized) rather than
  hand-rolled TTLs unless there's a specific need.

### DNS

- Route53 alias records, both **A and AAAA**, pointing at the distribution
  (CloudFront hosted zone `Z2FDTNDATAQYW2`).

### Deploy / update workflow

1. Deploy the ACM cert stack in `us-east-1` first (DNS-validated).
2. Deploy the CloudFront + S3 + Route53 stack in the primary region, passing the
   cert ARN.
3. Sync site files to the S3 bucket.
4. **Invalidate the CloudFront cache** (`/*`) after every content update, and tell
   the user it takes 1-3 minutes to propagate. Stale UI after deploy is almost
   always a missing invalidation.

See `templates/cloudfront-stack.yaml`, `templates/certificate-stack.yaml`, and
`templates/deploy-cloudfront.sh`.

## PWA and favicons

Every frontend ships a complete icon set and a web manifest:

- `favicon.ico`, `favicon.svg`
- PNG sizes (at least 16, 32, 48, 96/128), plus `apple-touch-icon.png`
- `manifest.json` with name, icons, theme colour, display mode

## Fallback: embedded frontend in Lambda

For very small apps, HTML/CSS/JS can be embedded into the API Lambda and served
directly (no S3/CloudFront). Trade-offs:

- Simpler and cheaper; one stack, one deploy.
- No CDN/edge caching, and every UI change redeploys the function.
- Use a build step to embed the static files into the handler before deploy.

Only choose this for trivial internal tools. Anything customer-facing or with more
than a couple of pages should use CloudFront.
