---
inclusion: always
---
<!-- kiro-template v2.0.0 -->

# Cost Standards

**Under $1/month idle per app** (shared parent Route53 zone excluded); typically
$0.10-0.50.

## Don't create without explicit user approval

Each breaks the idle target alone. Prices approximate: verify on AWS pricing pages
before quoting.

| Resource | Approx idle cost | Alternative |
|---|---|---|
| NAT Gateway | ~$30-45/mo each + data | No VPC |
| Interface VPC endpoints | ~$7-10/mo per endpoint per AZ | No VPC; public endpoints + IAM |
| Lambda provisioned concurrency | a few $/mo per unit | Accept cold starts; small packages |
| DynamoDB provisioned capacity | hourly, used or not | On-demand |
| AWS WAF | ~$5/mo per ACL + ~$1/rule | Stage throttling |
| Secrets Manager | ~$0.40/secret/mo | SSM `SecureString` (free) |
| Customer-managed KMS keys | ~$1/mo per key | AWS-managed keys |
| RDS/Aurora, OpenSearch, ElastiCache, Kinesis | ~$10-50+/mo each | DynamoDB on-demand, S3, scheduled Lambda |
| Cognito Plus | per-MAU, no free tier | Cognito Essentials |
| Extra Route53 hosted zones | ~$0.50/mo each | Records in the parent zone |
| API Gateway access/execution logs at volume | CloudWatch per GB | Off; Lambda logs |

Also ask before account-level changes: quota increases, paid support,
Organizations/SCPs.

## Rules

- Every design estimates an idle and a busy month per billable resource (README
  Cost section); flag step-changes.
- Lambda log groups declared in the stack, `RetentionInDays` 14-30.
- Monthly AWS Budget email alarm per account (`templates/budget-stack.yaml`; first two
  budgets free).
- Tag every resource `Project=<project>`so each project's cost shows separately in Cost Explorer. Confirm the <project> value with the user  
- Exact spelling: `Project` with a capital P. Values lowercase and hyphenated.
- Apply it at stack level so all resources inherit it:
  - CloudFormation: `aws cloudformation deploy ... --tags Project=<slug>`
  - Serverless Framework: set `provider.stackTags` and `provider.tags` to `Project: <slug>`
- Shape B bills memory while environments live (`web-functions.md`).
