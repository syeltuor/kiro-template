#!/bin/bash
# kiro-template v2.0.0
#
# DEPRECATED: use templates/scripts/deploy.sh instead (content-only default, --infra,
# guards, stack outputs, CSP). Kept for projects still on the v1 layout; updated to the
# v2 certificate-stack.yaml / cloudfront-stack.yaml parameters and outputs.
#
# CloudFront deployment for {{PROJECT_NAME}}.
# Deploys ACM cert (us-east-1) -> CloudFront + private S3 + Route53 (primary region),
# syncs the site, and invalidates the cache.

set -euo pipefail

# ---- Config -----------------------------------------------------------------
PROJECT="{{PROJECT_SLUG}}"
CERT_STACK_NAME="$PROJECT-certificate"
CLOUDFRONT_STACK_NAME="$PROJECT-cloudfront"
DOMAIN_NAME="{{DOMAIN}}"                 # e.g. app.example.com
PARENT_DOMAIN="{{PARENT_DOMAIN}}"        # e.g. example.com
SITE_DIR="staging"                       # folder that IS the site (synced as-is)
REGION="eu-west-2"
CERT_REGION="us-east-1"                  # CloudFront certs must be here
# -----------------------------------------------------------------------------

[ -f "$SITE_DIR/index.html" ] || { echo "❌ $SITE_DIR/index.html missing"; exit 1; }
echo "🚀 Deploying CloudFront for $DOMAIN_NAME"

# Look up the hosted zone ID dynamically (don't hardcode it)
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$PARENT_DOMAIN" \
    --query "HostedZones[?Name=='${PARENT_DOMAIN}.'].Id" \
    --output text | sed 's|/hostedzone/||')
[ -n "$HOSTED_ZONE_ID" ] && [ "$HOSTED_ZONE_ID" != "None" ] || { echo "❌ Hosted zone for $PARENT_DOMAIN not found"; exit 1; }

aws cloudformation deploy \
    --template-file certificate-stack.yaml \
    --stack-name "$CERT_STACK_NAME" \
    --parameter-overrides Project="$PROJECT" DomainName="$DOMAIN_NAME" HostedZoneId="$HOSTED_ZONE_ID" \
    --no-fail-on-empty-changeset \
    --region "$CERT_REGION"

CERT_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$CERT_STACK_NAME" --region "$CERT_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`CertificateArn`].OutputValue' \
    --output text)
[ -n "$CERT_ARN" ] && [ "$CERT_ARN" != "None" ] || { echo "❌ Could not read certificate ARN"; exit 1; }

aws cloudformation deploy \
    --template-file cloudfront-stack.yaml \
    --stack-name "$CLOUDFRONT_STACK_NAME" \
    --parameter-overrides \
        Project="$PROJECT" \
        DomainName="$DOMAIN_NAME" \
        HostedZoneId="$HOSTED_ZONE_ID" \
        CertificateArn="$CERT_ARN" \
    --no-fail-on-empty-changeset \
    --region "$REGION"

read_output() {
  aws cloudformation describe-stacks --stack-name "$CLOUDFRONT_STACK_NAME" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}
BUCKET=$(read_output SiteBucketName)
DISTRIBUTION_ID=$(read_output DistributionId)

aws s3 sync "$SITE_DIR/" "s3://$BUCKET" --region "$REGION" --delete \
    --exclude ".DS_Store" --exclude "*/.DS_Store" \
    --cache-control "public, max-age=0, s-maxage=86400, must-revalidate"
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/*' >/dev/null

echo ""
echo "✅ Done. https://$DOMAIN_NAME (invalidation takes 1-3 minutes)"
echo "   Note: first-time cert validation + distribution rollout can take 10-15 min."
