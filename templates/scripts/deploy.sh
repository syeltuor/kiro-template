#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Deploy the project. The ONLY supported way to deploy (never hand-run s3 sync).
#
# Usage: scripts/deploy.sh [--infra]
#
#   (default)  content only: guard, write staging/js/config.js (if there is an API or
#              Cognito), sync staging/ to S3 with --delete, invalidate CloudFront
#   --infra    lint, deploy the CloudFormation stacks in order, then the content phase
#
# Components are opt-in by template presence in infra/:
#   certificate-stack.yaml + cloudfront-stack.yaml   required (shapes A and A0)
#   artifacts-stack.yaml                             needed when there is Lambda code
#   data-stack.yaml                                  DynamoDB (needs TABLE_BASE_NAME)
#   cognito-stack.yaml                               only if the site needs auth
#   api-stack.yaml                                   shape A (packaged from services/api/src)
#
# Settings come from the gitignored .env (see .env.example). Bucket names, IDs and URLs
# come from stack outputs; nothing account-specific is hardcoded.
set -euo pipefail

usage() { echo "Usage: $0 [--infra]" >&2; exit 2; }

INFRA=0
while [ $# -gt 0 ]; do
  case "$1" in
    --infra) INFRA=1 ;;
    -h|--help) usage ;;
    *) echo "❌ Unknown argument: $1" >&2; usage ;;
  esac
  shift
done

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

: "${DOMAIN_NAME:?DOMAIN_NAME is not set (.env)}"
: "${PARENT_DOMAIN:?PARENT_DOMAIN is not set (.env)}"

# Guard before any AWS call: a wrong SITE_DIR plus --delete would wipe the live site.
[ -f "$SITE_DIR/index.html" ] || { echo "❌ $SITE_DIR/index.html missing"; exit 1; }

WITH_AUTH=0; has_template cognito-stack.yaml && WITH_AUTH=1
WITH_API=0;  has_template api-stack.yaml && WITH_API=1
WITH_DATA=0; has_template data-stack.yaml && WITH_DATA=1

# cfn_deploy STACK TEMPLATE REGION [extra args...]
cfn_deploy() {
  local stack="$1" template="$2" region="$3"; shift 3
  echo "📦 Deploying $stack ($region)..."
  aws cloudformation deploy \
    --stack-name "$stack" \
    --template-file "$template" \
    --region "$region" \
    --no-fail-on-empty-changeset \
    --tags "Project=$PROJECT" \
    "$@"
}

echo "🚀 Deploying $PROJECT to https://$DOMAIN_NAME (stage: $STAGE)"

if [ "$INFRA" -eq 1 ]; then
  for t in certificate-stack.yaml cloudfront-stack.yaml; do
    has_template "$t" || { echo "❌ $INFRA_DIR/$t missing"; exit 1; }
  done

  # Hosted zone: from .env, or looked up by name (never hardcoded).
  if [ -z "${HOSTED_ZONE_ID:-}" ]; then
    echo "📋 Looking up hosted zone for $PARENT_DOMAIN..."
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
      --dns-name "$PARENT_DOMAIN" \
      --query "HostedZones[?Name=='${PARENT_DOMAIN}.'].Id" \
      --output text | sed 's|/hostedzone/||')
  fi
  if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" = "None" ]; then
    echo "❌ Hosted zone for $PARENT_DOMAIN not found"; exit 1
  fi
  echo "✅ Hosted zone: $HOSTED_ZONE_ID"

  echo "🔎 Linting templates..."
  scripts/lint.sh

  mkdir -p build

  # 1. Certificate (us-east-1; CloudFront only reads certs from there).
  echo "⏳ The certificate waits for DNS validation (usually 2-5 minutes)."
  cfn_deploy "$CERT_STACK" "$INFRA_DIR/certificate-stack.yaml" "$CERT_REGION" \
    --parameter-overrides Project="$PROJECT" DomainName="$DOMAIN_NAME" HostedZoneId="$HOSTED_ZONE_ID"
  CERT_ARN=$(out "$CERT_STACK" CertificateArn "$CERT_REGION")

  # 2. Data
  if [ "$WITH_DATA" -eq 1 ]; then
    : "${TABLE_BASE_NAME:?TABLE_BASE_NAME is not set (.env), e.g. MyAppData}"
    cfn_deploy "$DATA_STACK" "$INFRA_DIR/data-stack.yaml" "$REGION" \
      --parameter-overrides Project="$PROJECT" TableBaseName="$TABLE_BASE_NAME" Stage="$STAGE"
  fi

  # 3. Auth (only when the site needs authentication)
  if [ "$WITH_AUTH" -eq 1 ]; then
    : "${COGNITO_DOMAIN_PREFIX:?COGNITO_DOMAIN_PREFIX is not set (.env)}"
    cfn_deploy "$AUTH_STACK" "$INFRA_DIR/cognito-stack.yaml" "$REGION" \
      --parameter-overrides Project="$PROJECT" AppUrl="https://$DOMAIN_NAME/" \
        CognitoDomainPrefix="$COGNITO_DOMAIN_PREFIX" AppDisplayName="${APP_DISPLAY_NAME:-$PROJECT}"
  fi

  # 4. API (packaged into the artifacts bucket)
  if [ "$WITH_API" -eq 1 ]; then
    has_template artifacts-stack.yaml || { echo "❌ $INFRA_DIR/artifacts-stack.yaml missing (needed to package the API)"; exit 1; }
    cfn_deploy "$ARTIFACTS_STACK" "$INFRA_DIR/artifacts-stack.yaml" "$REGION" \
      --parameter-overrides Project="$PROJECT"
    ARTIFACTS_BUCKET=$(out "$ARTIFACTS_STACK" ArtifactsBucketName)
    echo "📦 Packaging API..."
    aws cloudformation package --region "$REGION" \
      --template-file "$INFRA_DIR/api-stack.yaml" --s3-bucket "$ARTIFACTS_BUCKET" --s3-prefix api \
      --output-template-file build/api.packaged.yaml >/dev/null
    API_PARAMS=(Project="$PROJECT" Stage="$STAGE" AllowedOrigin="https://$DOMAIN_NAME"
                DataStackName="$DATA_STACK" AuthStackName="$AUTH_STACK")
    # Set NODE_RUNTIME in .env to the latest Lambda-supported Node.js runtime.
    if [ -n "${NODE_RUNTIME:-}" ]; then API_PARAMS+=(Runtime="$NODE_RUNTIME"); fi
    cfn_deploy "$API_STACK" build/api.packaged.yaml "$REGION" --capabilities CAPABILITY_IAM \
      --parameter-overrides "${API_PARAMS[@]}"
  fi

  # 5. CloudFront + private S3 + DNS. The CSP lists the API and Cognito origins.
  CONNECT="'self'"; FORM="'self'"
  if [ "$WITH_API" -eq 1 ]; then CONNECT="$CONNECT $(out "$API_STACK" ApiOrigin)"; fi
  if [ "$WITH_AUTH" -eq 1 ]; then
    COGNITO_BASE_URL=$(out "$AUTH_STACK" CognitoBaseUrl)
    CONNECT="$CONNECT $COGNITO_BASE_URL"; FORM="$FORM $COGNITO_BASE_URL"
  fi
  CSP="default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src $CONNECT; form-action $FORM; frame-ancestors 'none'; base-uri 'self'; object-src 'none'; manifest-src 'self'"
  echo "⏳ A new CloudFront distribution takes 5-15 minutes to roll out."
  cfn_deploy "$CLOUDFRONT_STACK" "$INFRA_DIR/cloudfront-stack.yaml" "$REGION" \
    --parameter-overrides Project="$PROJECT" DomainName="$DOMAIN_NAME" HostedZoneId="$HOSTED_ZONE_ID" \
      CertificateArn="$CERT_ARN" ContentSecurityPolicy="$CSP"
  echo "✅ Infrastructure deployed."
fi

# ---- Content phase (always) ----------------------------------------------------------
BUCKET=$(out "$CLOUDFRONT_STACK" SiteBucketName)
DISTRIBUTION_ID=$(out "$CLOUDFRONT_STACK" DistributionId)

if [ "$WITH_API" -eq 1 ] || [ "$WITH_AUTH" -eq 1 ]; then
  API_BASE_URL=""; CLIENT_ID=""; COGNITO_BASE_URL=""
  if [ "$WITH_API" -eq 1 ]; then API_BASE_URL=$(out "$API_STACK" ApiBaseUrl); fi
  if [ "$WITH_AUTH" -eq 1 ]; then
    CLIENT_ID=$(out "$AUTH_STACK" UserPoolClientId)
    COGNITO_BASE_URL=$(out "$AUTH_STACK" CognitoBaseUrl)
  fi
  echo "📝 Writing $SITE_DIR/js/config.js (generated, gitignored)..."
  mkdir -p "$SITE_DIR/js"
  cat > "$SITE_DIR/js/config.js" <<EOF
// GENERATED by scripts/deploy.sh. Do not edit, do not commit.
window.APP_CONFIG = Object.freeze({
  apiBaseUrl: "$API_BASE_URL",
  cognitoBaseUrl: "$COGNITO_BASE_URL",
  clientId: "$CLIENT_ID",
  redirectUri: "https://$DOMAIN_NAME/",
  scopes: "openid email profile"
});
EOF
fi

# No --content-type: the CLI guesses per file. Browsers revalidate (max-age=0),
# CloudFront caches a day (s-maxage) and the invalidation below refreshes it.
echo "📤 Syncing $SITE_DIR/ to s3://$BUCKET ..."
aws s3 sync "$SITE_DIR/" "s3://$BUCKET" --region "$REGION" --delete \
  --exclude ".DS_Store" --exclude "*/.DS_Store" --exclude "fixtures/*" \
  --cache-control "public, max-age=0, s-maxage=86400, must-revalidate"

echo "🔄 Invalidating CloudFront cache..."
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths '/*' >/dev/null

echo ""
echo "✅ Deployed. The invalidation takes 1-3 minutes to propagate."
echo "🔗 https://$DOMAIN_NAME"
