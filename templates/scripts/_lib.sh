#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Shared helpers for the project scripts. Sourced, not executed:
#   . "$(dirname "$0")/_lib.sh"
#
# Loads the gitignored .env from the project root, sets defaults and provides
# `out STACK KEY [REGION]` to read a CloudFormation output (aborts when empty).
# Bash 3.2 compatible (macOS default shell for scripts).

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

: "${PROJECT:?PROJECT is not set (add PROJECT=<slug> to .env)}"
if ! [[ "$PROJECT" =~ ^[a-z][a-z0-9-]{1,30}$ ]]; then
  echo "❌ PROJECT must be a lower-case slug (a-z, 0-9, -)" >&2
  exit 2
fi
REGION="${REGION:-${AWS_REGION:-eu-west-2}}"
CERT_REGION="${CERT_REGION:-us-east-1}"
STAGE="${STAGE:-app}"
PARAM_PREFIX="${PARAM_PREFIX:-/$PROJECT}"
INFRA_DIR="${INFRA_DIR:-infra}"
SITE_DIR="${SITE_DIR:-staging}"

CERT_STACK="$PROJECT-certificate"
ARTIFACTS_STACK="$PROJECT-artifacts"
DATA_STACK="$PROJECT-data"
AUTH_STACK="$PROJECT-auth"
API_STACK="$PROJECT-api"
CLOUDFRONT_STACK="$PROJECT-cloudfront"
export REGION CERT_REGION STAGE PARAM_PREFIX

# out STACK KEY [REGION]: print a stack output, abort if it is missing.
out() {
  local stack="$1" key="$2" region="${3:-$REGION}" val
  val=$(aws cloudformation describe-stacks --stack-name "$stack" --region "$region" \
          --query "Stacks[0].Outputs[?OutputKey=='$key'].OutputValue" --output text 2>/dev/null || true)
  if [ -z "$val" ] || [ "$val" = "None" ]; then
    echo "❌ Output $key missing from stack $stack ($region)" >&2
    exit 1
  fi
  printf '%s' "$val"
}

# has_template NAME: true if infra/NAME exists (the project opted into that component).
has_template() { [ -f "$INFRA_DIR/$1" ]; }
