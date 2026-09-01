#!/bin/bash
#
# Generic API deploy for {{PROJECT_NAME}}.
# Packages the Lambda + deploys its CloudFormation stack, then prints the URL.

set -e

STAGE=${1:-app}
STACK_NAME="{{PROJECT_SLUG}}-api"
TEMPLATE="{{PROJECT_SLUG}}-api-stack.yaml"
REGION="eu-west-2"

echo "🚀 Deploying API stack '$STACK_NAME' to stage: $STAGE"

# Install deps if needed
[ ! -d "node_modules" ] && { echo "📦 npm install..."; npm install; }

# Deploy the stack (CAPABILITY_IAM for the Lambda execution role)
aws cloudformation deploy \
    --template-file "$TEMPLATE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides Stage="$STAGE" \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region "$REGION"

# Print the API base URL from stack outputs
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiBaseUrl`].OutputValue' \
    --output text)

echo ""
echo "✅ API deployed."
echo "🔗 Base URL: $API_URL"
echo ""
echo "💡 View logs:  aws logs tail /aws/lambda/{{PROJECT_SLUG}}-api --follow --region $REGION"
