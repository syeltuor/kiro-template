#!/bin/bash
#
# CloudFront deployment for {{PROJECT_NAME}}.
# Deploys ACM cert (us-east-1) -> CloudFront + S3 + Route53 (primary region),
# syncs the site, and invalidates the cache.
#
# Replace the placeholder values below before first run.

set -e

# ---- Config -----------------------------------------------------------------
CERT_STACK_NAME="{{PROJECT_SLUG}}-certificate"
CLOUDFRONT_STACK_NAME="{{PROJECT_SLUG}}-cloudfront"
DOMAIN_NAME="{{DOMAIN}}"                 # e.g. app.example.co.uk
PARENT_DOMAIN="{{PARENT_DOMAIN}}"        # e.g. example.co.uk
S3_BUCKET="{{PROJECT_SLUG}}-ui"
SITE_DIR="."                             # folder containing the static files
REGION="eu-west-2"
CERT_REGION="us-east-1"                  # CloudFront certs must be here
# -----------------------------------------------------------------------------

echo "🚀 Deploying CloudFront for $DOMAIN_NAME"

# Look up the hosted zone ID dynamically (don't hardcode it)
echo "📋 Looking up hosted zone for $PARENT_DOMAIN..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "$PARENT_DOMAIN" \
    --query "HostedZones[?Name=='${PARENT_DOMAIN}.'].Id" \
    --output text | sed 's|/hostedzone/||')
[ -z "$HOSTED_ZONE_ID" ] && { echo "❌ Hosted zone for $PARENT_DOMAIN not found"; exit 1; }
echo "✅ Hosted zone: $HOSTED_ZONE_ID"

# Ensure the bucket exists
aws s3 ls "s3://$S3_BUCKET" >/dev/null 2>&1 || { echo "❌ Bucket $S3_BUCKET missing"; exit 1; }

# Step 1: certificate in us-east-1
echo "📜 Deploying certificate stack (us-east-1)..."
aws cloudformation deploy \
    --template-file certificate-stack.yaml \
    --stack-name "$CERT_STACK_NAME" \
    --parameter-overrides DomainName="$DOMAIN_NAME" HostedZoneId="$HOSTED_ZONE_ID" \
    --region "$CERT_REGION"

CERT_ARN=$(aws cloudformation describe-stacks \
    --stack-name "$CERT_STACK_NAME" --region "$CERT_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`SSLCertificateArn`].OutputValue' \
    --output text)
[ -z "$CERT_ARN" ] && { echo "❌ Could not read certificate ARN"; exit 1; }
echo "✅ Certificate: $CERT_ARN"

# Step 2: CloudFront + S3 + Route53
echo "📦 Deploying CloudFront stack..."
aws cloudformation deploy \
    --template-file cloudfront-stack.yaml \
    --stack-name "$CLOUDFRONT_STACK_NAME" \
    --parameter-overrides \
        DomainName="$DOMAIN_NAME" \
        HostedZoneId="$HOSTED_ZONE_ID" \
        S3BucketName="$S3_BUCKET" \
        CertificateArn="$CERT_ARN" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION"

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name "$CLOUDFRONT_STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

# Step 3: sync files and invalidate cache
echo "📤 Syncing $SITE_DIR to s3://$S3_BUCKET ..."
aws s3 sync "$SITE_DIR" "s3://$S3_BUCKET" --delete \
    --exclude "*.yaml" --exclude "*.sh" --exclude "*.md"

echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/*' >/dev/null

echo ""
echo "✅ Done. https://$DOMAIN_NAME"
echo "   Distribution: $DISTRIBUTION_ID"
echo "   Note: first-time cert validation + distribution rollout can take 10-15 min."
