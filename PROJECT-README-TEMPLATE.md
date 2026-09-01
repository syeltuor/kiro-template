<!--
  Generic README template for a serverless AWS project.
  Copy to your project root as README.md and replace all {{PLACEHOLDERS}}.
  Delete sections that don't apply (e.g. scheduled jobs, admin API).
-->

# {{PROJECT_NAME}}

{{ONE_LINE_DESCRIPTION}} Built serverless on AWS (Lambda + API Gateway + DynamoDB),
with a static frontend served via CloudFront.

## Features

- {{FEATURE_1}}
- {{FEATURE_2}}
- {{FEATURE_3}}
- Serverless architecture, scales automatically, pay only for usage

## Project structure

```
{{project-slug}}/
├── api/                  # Lambda APIs + CloudFormation stacks
├── ui/                   # Static frontend (S3 + CloudFront)
│   ├── index.html
│   ├── admin.html            # Authenticated admin page
│   ├── certificate-stack.yaml
│   ├── cloudfront-stack.yaml
│   └── deploy-cloudfront.sh
├── scripts/              # Setup / maintenance scripts
└── README.md
```

## Architecture

```
Users ──HTTPS──▶ CloudFront ──▶ S3 (static UI)
                     │
Client JS ──▶ API Gateway ──▶ Lambda ──▶ DynamoDB
```

- **Frontend**: static HTML/CSS/JS in S3, behind CloudFront (OAC, HTTPS, custom domain)
- **Backend**: AWS Lambda + API Gateway (REST)
- **Database**: DynamoDB (on-demand billing)
- **Region**: {{REGION}} (ACM cert for CloudFront in us-east-1)

## Prerequisites

- AWS account with credentials configured (`aws configure`)
- Node.js 20.x {{AND_PYTHON_IF_NEEDED}}
- A Route53 hosted zone for `{{PARENT_DOMAIN}}`

## Quick start

### Deploy the API
```bash
cd api
./deploy-api.sh {{STAGE}}
```

### Deploy the frontend (CloudFront + S3)
```bash
cd ui
./deploy-cloudfront.sh
# then sync files and invalidate cache
```

App URL: `https://{{DOMAIN}}`

## API endpoints

### Public
- `GET {{BASE_URL}}/{{resource}}` - {{description}}
- `GET {{BASE_URL}}/{{resource}}/{id}` - {{description}}

### Authenticated (admin)
Send the key/token as described in Security below.
- `POST {{BASE_URL}}/admin/{{resource}}` - {{description}}
- `PUT {{BASE_URL}}/admin/{{resource}}/{id}` - {{description}}
- `DELETE {{BASE_URL}}/admin/{{resource}}/{id}` - {{description}}

## Security

- Public read endpoints; all writes and admin surfaces are authenticated.
- **Auth method**: {{API_KEY_OR_TOKEN}}
  - API Key: send `x-api-key: <key>`. Retrieve the key from the API stack output
    or `aws apigateway get-api-key --include-value`.
  - Token: send `X-Admin-Token: <token>`. Set via the `ADMIN_TOKEN` env var.
- Secrets are **not** stored in this repo. See `.env.example` for required keys.
- HTTPS enforced, TLS 1.2 minimum. CORS restricted to `https://{{DOMAIN}}`.
- Rate limiting: {{USAGE_PLAN_OR_THROTTLING}} (e.g. burst 100, rate 50 req/s).

## Cost

Typical monthly cost at small scale: **{{COST_ESTIMATE}}** (Lambda + API Gateway +
DynamoDB + CloudFront, largely within free tier).

## Maintenance

```bash
# View logs
{{LOGS_COMMAND}}

# Get live URLs
{{GET_URLS_COMMAND}}

# Invalidate CloudFront cache after a UI update
aws cloudfront create-invalidation --distribution-id {{DIST_ID}} --paths '/*'
```

## Troubleshooting

- **Stale UI after deploy**: CloudFront cache not invalidated. Run the
  invalidation above and wait 1-3 minutes.
- **403 on admin API**: missing or wrong API key / token.
- **API returns stale data**: check the Lambda is pointed at the right table and
  that recent writes landed in DynamoDB.

## Documentation

- `DEPLOYMENT.md` - detailed deployment guide
- `SECURITY.md` - auth and secrets handling
