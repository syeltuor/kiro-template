#!/usr/bin/env bash
#
# install.sh — drop the AWS serverless project standards into a project.
#
# Fetches this standards repo and copies the Kiro steering files (and, optionally,
# the README template and infra templates) into a target project. Safe by default:
# existing files are backed up, never silently overwritten.
#
# Usage:
#   # From anywhere (installs into the current directory):
#   curl -fsSL https://raw.githubusercontent.com/{{GH_USER}}/{{REPO}}/main/install.sh | bash
#
#   # Or clone and run against a specific project:
#   ./install.sh [TARGET_DIR] [options]
#
# Options:
#   --templates       Also copy templates/ (CloudFront/cert stacks, deploy + auth)
#   --readme          Also copy PROJECT-README-TEMPLATE.md (as README.md if absent)
#   --all             Steering + templates + readme
#   --force           Overwrite existing files (a .bak copy is still made)
#   -h, --help        Show this help
#
# Env overrides:
#   STANDARDS_REPO    Git URL of the standards repo (default below)
#   STANDARDS_BRANCH  Branch to pull (default: main)

set -euo pipefail

# ---- Config -----------------------------------------------------------------
# NOTE: keep the default URL on its own line. Do not inline it into ${VAR:-...}:
# the `}` characters in the {{PLACEHOLDER}} tokens would break that expansion.
DEFAULT_REPO="https://github.com/{{GH_USER}}/{{REPO}}.git"
REPO_URL="${STANDARDS_REPO:-$DEFAULT_REPO}"
BRANCH="${STANDARDS_BRANCH:-main}"
# -----------------------------------------------------------------------------

TARGET_DIR="."
INCLUDE_TEMPLATES=false
INCLUDE_README=false
FORCE=false

# ---- Pretty output ----------------------------------------------------------
c_info()  { printf '\033[0;34m•\033[0m %s\n' "$1"; }
c_ok()    { printf '\033[0;32m✓\033[0m %s\n' "$1"; }
c_warn()  { printf '\033[0;33m!\033[0m %s\n' "$1"; }
c_err()   { printf '\033[0;31m✗\033[0m %s\n' "$1" >&2; }

usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ---- Parse args -------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --templates) INCLUDE_TEMPLATES=true ;;
    --readme)    INCLUDE_README=true ;;
    --all)       INCLUDE_TEMPLATES=true; INCLUDE_README=true ;;
    --force)     FORCE=true ;;
    -h|--help)   usage ;;
    -*)          c_err "Unknown option: $1"; exit 1 ;;
    *)           TARGET_DIR="$1" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || { c_err "git is required but not installed."; exit 1; }

mkdir -p "$TARGET_DIR"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
c_info "Target project: $TARGET_DIR"

# ---- Fetch the standards repo into a temp dir -------------------------------
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

c_info "Fetching standards from $REPO_URL ($BRANCH)..."
if ! git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/standards" 2>/dev/null; then
  c_err "Could not clone $REPO_URL (branch $BRANCH)."
  c_err "Set STANDARDS_REPO to the correct URL, or check the branch name."
  exit 1
fi
SRC="$TMP_DIR/standards"
c_ok "Standards downloaded."

# ---- Copy helper: back up existing files, respect --force -------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
copy_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    if [ "$FORCE" = true ]; then
      cp "$dest" "${dest}.bak-${STAMP}"
      cp "$src" "$dest"
      c_warn "Overwrote $(basename "$dest") (backup: ${dest##*/}.bak-${STAMP})"
    else
      c_warn "Skipped existing $dest (use --force to overwrite)"
    fi
  else
    cp "$src" "$dest"
    c_ok "Added ${dest#$TARGET_DIR/}"
  fi
}

# ---- 1. Steering files (always) ---------------------------------------------
c_info "Installing Kiro steering files..."
for f in "$SRC"/.kiro/steering/*.md; do
  [ -e "$f" ] || continue
  copy_file "$f" "$TARGET_DIR/.kiro/steering/$(basename "$f")"
done

# ---- 2. Templates (optional) ------------------------------------------------
if [ "$INCLUDE_TEMPLATES" = true ]; then
  c_info "Installing infra templates..."
  while IFS= read -r -d '' f; do
    rel="${f#$SRC/templates/}"
    copy_file "$f" "$TARGET_DIR/templates/$rel"
  done < <(find "$SRC/templates" -type f -print0)
  # keep shell scripts executable
  find "$TARGET_DIR/templates" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# ---- 3. README template (optional) ------------------------------------------
if [ "$INCLUDE_README" = true ]; then
  if [ -f "$TARGET_DIR/README.md" ] && [ "$FORCE" != true ]; then
    copy_file "$SRC/PROJECT-README-TEMPLATE.md" "$TARGET_DIR/PROJECT-README-TEMPLATE.md"
    c_warn "README.md already exists — dropped PROJECT-README-TEMPLATE.md instead."
  else
    copy_file "$SRC/PROJECT-README-TEMPLATE.md" "$TARGET_DIR/README.md"
  fi
fi

# ---- Done -------------------------------------------------------------------
echo
c_ok "Standards installed."
echo
echo "Next steps:"
echo "  1. Open the project in Kiro — steering files load automatically."
echo "  2. Replace {{PLACEHOLDERS}} in any copied README/templates."
[ "$INCLUDE_TEMPLATES" != true ] && echo "  3. Re-run with --templates to also copy the CloudFront/auth infra templates."
echo
