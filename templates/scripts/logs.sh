#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Tail a Lambda's CloudWatch logs: /aws/lambda/<project>-<component>.
#
# Usage: scripts/logs.sh [component] [--since 10m]     (component defaults to "api")
set -euo pipefail
usage() { echo "Usage: $0 [component] [--since 10m]" >&2; exit 2; }

COMPONENT="api"
SINCE="10m"
while [ $# -gt 0 ]; do
  case "$1" in
    --since) [ $# -ge 2 ] || usage; SINCE="$2"; shift ;;
    -h|--help) usage ;;
    -*) echo "❌ Unknown argument: $1" >&2; usage ;;
    *) COMPONENT="$1" ;;
  esac
  shift
done
[[ "$COMPONENT" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || { echo "❌ component must be a slug like api or ingest" >&2; exit 2; }
[[ "$SINCE" =~ ^[0-9]+[smhdw]$ ]] || { echo "❌ --since must look like 30m, 1h, 2d" >&2; exit 2; }

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

LOG_GROUP="/aws/lambda/$PROJECT-$COMPONENT"
echo "📜 Tailing $LOG_GROUP (since $SINCE, Ctrl-C to stop)"
exec aws logs tail "$LOG_GROUP" --region "$REGION" --follow --format short --since "$SINCE"
