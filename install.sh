#!/usr/bin/env bash
# kiro-template v2.0.0
#
# install.sh: drop the Kiro AWS serverless standards into a project.
#
# Fetches this standards repo and copies the Kiro steering files (and, optionally,
# the README template, infra templates and project scripts) into a target project.
# Safe by default: existing files are skipped; --force overwrites after making a
# .bak-<timestamp> copy.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/syeltuor/kiro-template/main/install.sh \
#     | bash -s -- ./my-project --all
#   ./install.sh [TARGET_DIR] [options]
#
# See usage() below for options and environment overrides.

set -euo pipefail

# ---- Config -----------------------------------------------------------------
DEFAULT_REPO="https://github.com/syeltuor/kiro-template.git"
DEFAULT_REF="main"
REPO_URL="${STANDARDS_REPO:-$DEFAULT_REPO}"
# STANDARDS_REF is a branch or a tag (main, v1, v1.0.0, v2 ...).
# STANDARDS_BRANCH is the deprecated v1 name for the same thing.
REF="${STANDARDS_REF:-${STANDARDS_BRANCH:-$DEFAULT_REF}}"
# -----------------------------------------------------------------------------

TARGET_DIR="."
INCLUDE_TEMPLATES=false
INCLUDE_SCRIPTS=false
INCLUDE_README=false
FORCE=false

# ---- Pretty output ----------------------------------------------------------
c_info()  { printf '\033[0;34m•\033[0m %s\n' "$1"; }
c_ok()    { printf '\033[0;32m✓\033[0m %s\n' "$1"; }
c_warn()  { printf '\033[0;33m!\033[0m %s\n' "$1"; }
c_err()   { printf '\033[0;31m✗\033[0m %s\n' "$1" >&2; }

usage() {
  cat <<'EOF'
install.sh: install the Kiro AWS serverless standards into a project.

Usage: install.sh [TARGET_DIR] [options]      (TARGET_DIR defaults to .)

Options:
  (none)        Steering files only, into TARGET/.kiro/steering/
  --templates   Also copy templates/ (CloudFormation stacks, auth helpers, scripts)
                into TARGET/templates/ for reference
  --scripts     Also install ready-to-use scripts into TARGET/scripts/, plus
                .env.example and .gitignore (from templates/gitignore) if absent
  --readme      Also copy PROJECT-README-TEMPLATE.md (as README.md if absent)
  --all         Steering + templates + scripts + readme
  --force       Overwrite existing files (a .bak-<timestamp> copy is made first)
  -h, --help    Show this help

Environment:
  STANDARDS_REPO    Git URL or local path of the standards repo
                    (default https://github.com/syeltuor/kiro-template.git)
  STANDARDS_REF     Branch or tag to install (default main = latest, v2)
                    e.g. STANDARDS_REF=v1 to install the v1 standards
  STANDARDS_BRANCH  Deprecated alias for STANDARDS_REF

Always written: TARGET/.kiro/.standards-version (what was installed, from where).
EOF
  exit 0
}

# ---- Parse args -------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --templates) INCLUDE_TEMPLATES=true ;;
    --scripts)   INCLUDE_SCRIPTS=true ;;
    --readme)    INCLUDE_README=true ;;
    --all)       INCLUDE_TEMPLATES=true; INCLUDE_SCRIPTS=true; INCLUDE_README=true ;;
    --force)     FORCE=true ;;
    -h|--help)   usage ;;
    -*)          c_err "Unknown option: $1"; exit 1 ;;
    *)           TARGET_DIR="$1" ;;
  esac
  shift
done

if [ -n "${STANDARDS_BRANCH:-}" ] && [ -z "${STANDARDS_REF:-}" ]; then
  c_warn "STANDARDS_BRANCH is deprecated; use STANDARDS_REF (branch or tag)."
fi

command -v git >/dev/null 2>&1 || { c_err "git is required but not installed."; exit 1; }

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
c_info "Target project: $TARGET_DIR"

# ---- Fetch the standards repo into a temp dir -------------------------------
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

c_info "Fetching standards from $REPO_URL ($REF)..."
if ! GIT_TERMINAL_PROMPT=0 git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$REF" \
       "$REPO_URL" "$TMP_DIR/standards" 2>/dev/null; then
  c_err "Could not clone $REPO_URL (ref $REF)."
  c_err "Check STANDARDS_REPO, and that STANDARDS_REF names an existing branch or tag."
  exit 1
fi
SRC="$TMP_DIR/standards"
COMMIT="$(git -C "$SRC" rev-parse --short HEAD)"
VERSION="pre-2.0 (no VERSION file)"
[ -f "$SRC/VERSION" ] && VERSION="$(tr -d '[:space:]' < "$SRC/VERSION")"
c_ok "Standards downloaded: version $VERSION (ref $REF, commit $COMMIT)."

# ---- Copy helper: skip existing files unless --force (which backs up first) --
STAMP="$(date +%Y%m%d-%H%M%S)"
ADDED=0; SKIPPED=0; OVERWRITTEN=0
copy_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    if [ "$FORCE" = true ]; then
      cp -p "$dest" "${dest}.bak-${STAMP}"
      cp "$src" "$dest"
      c_warn "Overwrote ${dest#"$TARGET_DIR"/} (backup: ${dest##*/}.bak-${STAMP})"
      OVERWRITTEN=$((OVERWRITTEN + 1))
    else
      c_warn "Skipped existing ${dest#"$TARGET_DIR"/} (use --force to overwrite)"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    cp "$src" "$dest"
    c_ok "Added ${dest#"$TARGET_DIR"/}"
    ADDED=$((ADDED + 1))
  fi
  case "$dest" in *.sh|*.py|*.mjs) chmod +x "$dest" ;; esac
}

# ---- 1. Steering files (always) ---------------------------------------------
# The source repo stores these under kiro/steering (no dot). The target project
# needs them under .kiro/steering (dotted) so Kiro picks them up.
c_info "Installing Kiro steering files..."
for f in "$SRC"/kiro/steering/*.md; do
  [ -e "$f" ] || continue
  copy_file "$f" "$TARGET_DIR/.kiro/steering/$(basename "$f")"
done

# ---- 2. Templates (optional, reference copies) ------------------------------
if [ "$INCLUDE_TEMPLATES" = true ]; then
  c_info "Installing templates/ ..."
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/templates/}"
    copy_file "$f" "$TARGET_DIR/templates/$rel"
  done < <(find "$SRC/templates" -type f ! -name '.DS_Store' -print0)
fi

# ---- 3. Scripts (optional, ready to use) ------------------------------------
if [ "$INCLUDE_SCRIPTS" = true ]; then
  if [ -d "$SRC/templates/scripts" ]; then
    c_info "Installing scripts/ ..."
    for f in "$SRC"/templates/scripts/*; do
      [ -f "$f" ] || continue
      copy_file "$f" "$TARGET_DIR/scripts/$(basename "$f")"
    done
    [ -f "$SRC/templates/.env.example" ] && copy_file "$SRC/templates/.env.example" "$TARGET_DIR/.env.example"
    [ -f "$SRC/templates/gitignore" ] && copy_file "$SRC/templates/gitignore" "$TARGET_DIR/.gitignore"
  else
    c_warn "This ref ($REF) has no templates/scripts; nothing to install for --scripts."
  fi
fi

# ---- 4. README template (optional) ------------------------------------------
if [ "$INCLUDE_README" = true ]; then
  if [ -f "$TARGET_DIR/README.md" ] && [ "$FORCE" != true ]; then
    copy_file "$SRC/PROJECT-README-TEMPLATE.md" "$TARGET_DIR/PROJECT-README-TEMPLATE.md"
    c_warn "README.md already exists: dropped PROJECT-README-TEMPLATE.md instead."
  else
    copy_file "$SRC/PROJECT-README-TEMPLATE.md" "$TARGET_DIR/README.md"
  fi
fi

# ---- 5. Record what was installed (installer metadata, always refreshed) ----
mkdir -p "$TARGET_DIR/.kiro"
cat > "$TARGET_DIR/.kiro/.standards-version" <<EOF
version=$VERSION
ref=$REF
commit=$COMMIT
repo=$REPO_URL
installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
c_ok "Wrote .kiro/.standards-version"

# ---- Done -------------------------------------------------------------------
echo
c_ok "Kiro AWS serverless standards $VERSION installed ($ADDED added, $SKIPPED skipped, $OVERWRITTEN overwritten)."
echo
echo "Next steps:"
echo "  1. Open the project in Kiro: steering files load automatically."
echo "  2. Replace {{PLACEHOLDERS}} in any copied README/templates."
if [ "$INCLUDE_SCRIPTS" = true ]; then
  echo "  3. cp .env.example .env and fill it in; copy the stacks you need from"
  echo "     templates/*-stack.yaml (installed with --templates) into infra/."
else
  echo "  3. Re-run with --scripts (or --all) for the deploy/lint/privacy scripts and stack templates."
fi
echo
