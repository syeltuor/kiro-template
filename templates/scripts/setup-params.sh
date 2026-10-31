#!/usr/bin/env bash
# kiro-template v2.0.0
#
# SSM Parameter Store helper for /<project>/... config and secrets (standard tier, free).
#
# Usage:
#   scripts/setup-params.sh secure NAME [--force]        prompt (hidden) -> SecureString
#   scripts/setup-params.sh string NAME [--force]        prompt (hidden) -> String
#   scripts/setup-params.sh string NAME --value VALUE [--force]
#                                                        non-sensitive config only
#   scripts/setup-params.sh check NAME [NAME...]         existence only (agents use this)
#   scripts/setup-params.sh list                         names and types under the prefix
#
# NAME is relative to PARAM_PREFIX (default /<project>), e.g. upstream/api-key.
#
# Rules (security-standards):
#   - The USER runs `secure` / `string` themselves. Values are read at a hidden prompt
#     (read -rs), never passed as script arguments, never pasted into chat.
#   - Personal identifiers (meter/device IDs, addresses, postcodes, coordinates) are
#     treated like secrets: enter them at the prompt too.
#   - This script never prints a value and never decrypts. Agents only run `check`.
#   - SecureStrings use the AWS-managed key alias/aws/ssm (no KMS cost).
#   - The value is passed to the AWS CLI as an argument, so it is briefly visible in the
#     local process list. Run this on your own machine, not a shared host.
set -euo pipefail

usage() { sed -n '4,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
[ $# -ge 1 ] || usage
CMD="$1"; shift

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

full_name() {
  local n="$1"
  if ! [[ "$n" =~ ^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$ ]] || [[ "/$n/" == */./* ]] || [[ "/$n/" == */../* ]]; then
    echo "❌ bad parameter name: $n" >&2; exit 2
  fi
  printf '%s/%s' "$PARAM_PREFIX" "$n"
}

put() { # TYPE NAME FORCE VALUE
  local type="$1" name="$2" force="$3" value="$4" err
  local -a args=(--region "$REGION" --type "$type" --name "$name" --value "$value")
  if [ "$type" = SecureString ]; then args+=(--key-id alias/aws/ssm); fi
  if [ "$force" -eq 1 ]; then args+=(--overwrite); fi
  if err=$(aws ssm put-parameter "${args[@]}" 2>&1 >/dev/null); then
    echo "  $name: set ($type)"
  elif printf '%s' "$err" | grep -q ParameterAlreadyExists; then
    echo "  $name: already exists (skipped; use --force to overwrite)"
  else
    # Print only the error code, never the request (which holds the value).
    echo "  $name: FAILED ($(printf '%s' "$err" | grep -o 'An error occurred ([A-Za-z]*)' | head -1))" >&2
    return 1
  fi
}

case "$CMD" in
  secure|string)
    [ $# -ge 1 ] || usage
    NAME=$(full_name "$1"); shift
    FORCE=0; VALUE=""; HAVE_VALUE=0
    while [ $# -gt 0 ]; do
      case "$1" in
        --force) FORCE=1 ;;
        --value)
          [ "$CMD" = string ] || { echo "❌ --value is not allowed for secrets; use the prompt" >&2; exit 2; }
          [ $# -ge 2 ] || usage; VALUE="$2"; HAVE_VALUE=1; shift ;;
        *) echo "❌ Unknown argument: $1" >&2; usage ;;
      esac
      shift
    done
    if [ "$HAVE_VALUE" -eq 0 ]; then
      printf 'Value for %s (input hidden): ' "$NAME" >&2
      IFS= read -rs VALUE
      echo >&2
    fi
    [ -n "$VALUE" ] || { echo "❌ empty value, nothing written" >&2; exit 2; }
    TYPE=String; [ "$CMD" = secure ] && TYPE=SecureString
    rc=0
    put "$TYPE" "$NAME" "$FORCE" "$VALUE" || rc=$?
    VALUE=""; unset VALUE
    exit "$rc"
    ;;
  check)
    [ $# -ge 1 ] || usage
    rc=0
    for short in "$@"; do
      n=$(full_name "$short")
      # No --with-decryption and only the InvalidParameters list is printed.
      missing=$(aws ssm get-parameters --region "$REGION" --names "$n" \
                  --query 'InvalidParameters' --output text)
      if [ -n "$missing" ] && [ "$missing" != "None" ]; then
        echo "  $n: MISSING"; rc=1
      else
        echo "  $n: exists"
      fi
    done
    exit "$rc"
    ;;
  list)
    aws ssm get-parameters-by-path --region "$REGION" --path "$PARAM_PREFIX" --recursive \
      --query 'Parameters[].[Name,Type]' --output text
    ;;
  *) usage ;;
esac
