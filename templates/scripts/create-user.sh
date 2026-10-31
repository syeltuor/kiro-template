#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Create a Cognito login user (admin-create-only pools). Cognito emails a temporary
# password; the user sets their own password at first sign-in. Nothing secret is printed.
#
# Usage: scripts/create-user.sh <email>
set -euo pipefail
[ $# -eq 1 ] || { echo "Usage: $0 <email>" >&2; exit 2; }
EMAIL="$1"
# Validate before any AWS call.
if ! [[ "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  echo "❌ Not a valid email address" >&2
  exit 2
fi

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

POOL=$(out "$AUTH_STACK" UserPoolId)
ERR=$(mktemp)
trap 'rm -f "$ERR"' EXIT
if aws cognito-idp admin-create-user --region "$REGION" \
     --user-pool-id "$POOL" \
     --username "$EMAIL" \
     --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
     --desired-delivery-mediums EMAIL >/dev/null 2>"$ERR"; then
  echo "✅ User created. Cognito has emailed a temporary password (check spam if it doesn't arrive)."
elif grep -q UsernameExistsException "$ERR"; then
  echo "ℹ  User already exists. To resend the invite:"
  echo "   aws cognito-idp admin-create-user --region $REGION --user-pool-id $POOL --username <email> --message-action RESEND"
  echo "   or reset: aws cognito-idp admin-reset-user-password --region $REGION --user-pool-id $POOL --username <email>"
  exit 0
else
  cat "$ERR" >&2
  exit 1
fi
