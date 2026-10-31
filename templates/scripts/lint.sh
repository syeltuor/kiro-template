#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Lint the CloudFormation templates in infra/.
#
# 1. cfn-lint (pinned, installed into the gitignored .venv on first run) on copies in
#    build/lint/, where each local `Code: <path>` is replaced by a placeholder S3 object
#    (the raw templates use local paths that `aws cloudformation package` rewrites).
# 2. aws cloudformation validate-template on the ORIGINAL templates (read-only call;
#    certificate templates in us-east-1, the rest in the primary region).
#
# Usage: scripts/lint.sh [--offline]     (--offline skips validate-template)
set -euo pipefail
OFFLINE=0
case "${1:-}" in
  "") ;;
  --offline) OFFLINE=1 ;;
  *) echo "Usage: $0 [--offline]" >&2; exit 2 ;;
esac

# Bump deliberately; check https://pypi.org/project/cfn-lint/ at project start.
CFN_LINT_VERSION="${CFN_LINT_VERSION:-1.58.0}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
REGION="${REGION:-${AWS_REGION:-eu-west-2}}"
CERT_REGION="${CERT_REGION:-us-east-1}"
INFRA_DIR="${INFRA_DIR:-infra}"

shopt -s nullglob
TEMPLATES=("$INFRA_DIR"/*.yaml)
[ ${#TEMPLATES[@]} -gt 0 ] || { echo "❌ no templates in $INFRA_DIR/"; exit 1; }

if [ ! -x .venv/bin/cfn-lint ] || ! .venv/bin/cfn-lint --version 2>/dev/null | grep -qF "$CFN_LINT_VERSION"; then
  echo "📦 Installing cfn-lint==$CFN_LINT_VERSION into .venv..."
  [ -x .venv/bin/python ] || python3 -m venv .venv
  .venv/bin/pip install -q --disable-pip-version-check "cfn-lint==$CFN_LINT_VERSION"
fi

rm -rf build/lint
mkdir -p build/lint
python3 - "${TEMPLATES[@]}" <<'PY'
import pathlib, re, sys
pat = re.compile(r'^(\s*)Code:\s*(\.\.?/\S+)\s*$')
for src in sys.argv[1:]:
    p = pathlib.Path(src)
    out = [pat.sub(r'\1Code: {S3Bucket: lint-placeholder, S3Key: lint.zip}', l) for l in p.read_text().splitlines()]
    pathlib.Path('build/lint', p.name).write_text('\n'.join(out) + '\n')
PY

echo "🔎 $(.venv/bin/cfn-lint --version) on ${#TEMPLATES[@]} templates (build/lint copies)"
rc=0
.venv/bin/cfn-lint build/lint/*.yaml || rc=$?
# cfn-lint exit code is a bitmask: 2 = error, 4 = warning, 8 = informational.
if [ $((rc & 2)) -ne 0 ] || [ "$rc" -eq 1 ]; then
  echo "❌ cfn-lint reported errors (exit $rc)"
  exit 1
fi
if [ "$rc" -ne 0 ]; then
  echo "⚠  cfn-lint reported warnings/informational findings only (exit $rc)"
else
  echo "✅ cfn-lint: 0 errors, 0 warnings"
fi

if [ "$OFFLINE" -eq 1 ]; then
  echo "PARTIAL: validate-template not run (--offline)"
  exit 0
fi

ok=0
for t in "${TEMPLATES[@]}"; do
  region="$REGION"
  case "$(basename "$t")" in *certificate*) region="$CERT_REGION" ;; esac
  if aws cloudformation validate-template --region "$region" --template-body "file://$t" >/dev/null; then
    echo "✅ validate-template $t ($region)"
    ok=$((ok + 1))
  else
    echo "❌ validate-template failed: $t ($region)"
    exit 1
  fi
done
echo "✅ lint complete: cfn-lint 0 errors, validate-template OK x$ok"
