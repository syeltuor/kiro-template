---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Cost Standards

**Principle: an app nobody uses should cost close to nothing.**

**Target: under $1/month idle per app** (the shared Route53 hosted zone for the
parent domain is excluded). Most small apps built to these standards land at
$0.10-0.50/month.

## Don't create these without explicit user approval

Each one has a fixed monthly cost that breaks the idle target on its own. Prices
are approximate, region-dependent and change. **Verify on the AWS pricing pages**
before quoting them.

| Resource | Approx. idle cost | Cheaper alternative |
|---|---|---|
| NAT Gateway | ~$30-45/month each, plus data processing | No VPC. Lambda outside a VPC reaches the internet directly |
| Interface VPC endpoints (PrivateLink) | ~$7-10/month per endpoint per AZ | No VPC; public AWS endpoints over TLS with IAM |
| Lambda provisioned concurrency | a few $/month per unit, always on | Accept cold starts; keep packages small; arm64 |
| DynamoDB provisioned capacity | billed per hour whether used or not | On-demand (`PAY_PER_REQUEST`) |
| AWS WAF | ~$5/month per web ACL + ~$1 per rule + requests | Stage throttling, CloudFront, Cognito |
| Secrets Manager | ~$0.40/secret/month + API calls | SSM Parameter Store standard `SecureString` (free) |
| Customer-managed KMS keys | ~$1/month per key + requests | AWS-managed keys (`aws/ssm`, SSE-S3, DynamoDB default) |
| RDS / Aurora, OpenSearch, ElastiCache, Kinesis | ~$10-50+/month each, always on | DynamoDB on-demand; S3; scheduled Lambda |
| Cognito Plus tier | per-MAU, **no free tier** | Cognito Essentials (free tier covers small apps) |
| Extra Route53 hosted zones | ~$0.50/month each | Subdomain records in the existing parent zone |
| API Gateway access/execution logging at volume | CloudWatch ingestion per GB | Metrics off by default; Lambda logs with retention |

## Rules

- **Every design states two estimates**: an idle month and a busy month, listing
  each billable resource with its usage assumption (see the PROJECT README Cost
  section). Flag anything that causes a step-change in cost.
- **Log retention**: every Lambda log group is declared in the stack with
  `RetentionInDays` of 14-30. Never leave the default "never expire".
- **Right-size schedules**: a job runs only as often as the data it refreshes can
  change or be seen. Daily data doesn't need an hourly job.
- **Explicit Lambda memory and timeout**; prefer `arm64`.
- **CloudFront**: `PriceClass_100`, managed `CachingOptimized` policy, compression.
- **Budget alarm in the baseline**: every account gets a monthly AWS Budget with an
  email alert (`templates/budget-stack.yaml`). The first two budgets per account
  are free (verify).
- **Favour free-tier-friendly services**: Lambda, API Gateway, DynamoDB on-demand,
  S3, CloudFront, SSM standard parameters, EventBridge Scheduler, ACM public certs.
- **Ask before account-level changes**: Service Quotas increases, paid support,
  paid account features, Organizations/SCP changes.
- **Check the real bill after a week** (Cost Explorer, filtered by the `Project`
  tag) and record it in the README Cost section next to the estimate.
- Tag every stack and resource with `Project=<project>` so cost can be filtered.

## Lambda Web Functions (exception shape B)

Web Functions bill memory **for as long as the execution environment exists**, on
top of requests and active CPU time. Environments scale to zero with no traffic,
but Lambda may keep spare environments warm ahead of demand. Don't assume idle
cost is near zero: check the current Lambda pricing page, estimate it in the
design, and confirm it on the real bill after a week. Never put this shape in a
VPC (NAT / endpoint costs).
