#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Print every output of the project's stacks (site URL, API URL, login URL, IDs).
# Outputs never contain secrets.
#
# Usage: scripts/get-urls.sh
set -euo pipefail
[ $# -eq 0 ] || { echo "Usage: $0" >&2; exit 2; }

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

show() { # STACK REGION
  local rows
  rows=$(aws cloudformation describe-stacks --stack-name "$1" --region "$2" \
           --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' --output text 2>/dev/null || true)
  echo "== $1 ($2)"
  if [ -z "$rows" ] || [ "$rows" = "None" ]; then
    echo "   (not deployed)"
  else
    printf '%s\n' "$rows" | while IFS=$'\t' read -r k v; do printf '   %-26s %s\n' "$k" "$v"; done
  fi
}

show "$CLOUDFRONT_STACK" "$REGION"
show "$API_STACK" "$REGION"
show "$AUTH_STACK" "$REGION"
show "$DATA_STACK" "$REGION"
show "$ARTIFACTS_STACK" "$REGION"
show "$CERT_STACK" "$CERT_REGION"
