#!/bin/bash
# kiro-template v2.0.0
#
# DEPRECATED: use templates/scripts/deploy.sh --infra instead (it lints, packages via
# the artifacts bucket and deploys every stack in order). Kept for projects still on
# the v1 layout; updated for the v2 api-stack.yaml.
#
# Packages the Lambda + deploys the API stack for {{PROJECT_NAME}}, then prints the URL.

set -euo pipefail

PROJECT="{{PROJECT_SLUG}}"
STAGE=${1:-app}
STACK_NAME="$PROJECT-api"
TEMPLATE="api-stack.yaml"
ARTIFACTS_BUCKET="{{ARTIFACTS_BUCKET}}"    # output of artifacts-stack.yaml
ALLOWED_ORIGIN="https://{{DOMAIN}}"
REGION="eu-west-2"

echo "🚀 Deploying API stack '$STACK_NAME' to stage: $STAGE"

mkdir -p build
aws cloudformation package --region "$REGION" \
    --template-file "$TEMPLATE" --s3-bucket "$ARTIFACTS_BUCKET" --s3-prefix api \
    --output-template-file build/api.packaged.yaml >/dev/null

aws cloudformation deploy \
    --template-file build/api.packaged.yaml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides Project="$PROJECT" Stage="$STAGE" AllowedOrigin="$ALLOWED_ORIGIN" \
        DataStackName="$PROJECT-data" AuthStackName="$PROJECT-auth" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset \
    --region "$REGION"

API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiBaseUrl`].OutputValue' \
    --output text)

echo ""
echo "✅ API deployed."
echo "🔗 Base URL: $API_URL"
echo ""
echo "💡 View logs:  aws logs tail /aws/lambda/$PROJECT-api --follow --region $REGION"
