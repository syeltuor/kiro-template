#!/usr/bin/env bash
# kiro-template v2.0.0
#
# privacy-check.sh: fail-closed scan for secrets and personal identifiers committed to
# the branch. Run before every push.
#
# Usage: scripts/privacy-check.sh [--offline] [--with-secrets] [--base SHA]
#
#   (default)       step 0 self-test, step 1 generic pattern grep, step 2 identifier
#                   literals read from SSM (PRIVACY_PARAMS)
#   --offline       steps 0 and 1 only; prints PARTIAL (literal checks not run)
#   --with-secrets  step 2 also reads PRIVACY_SECURE_PARAMS (SecureStrings, decrypted in
#                   memory only)
#   --base SHA      scan commits in SHA..HEAD (or env PRIVACY_BASE); default = root commit
#
# Configure in .env (names only, never values; relative to PARAM_PREFIX):
#   PRIVACY_PARAMS="home/postcode device/serial"     String identifiers to search for
#   PRIVACY_SECURE_PARAMS="upstream/account-number"  SecureStrings (with --with-secrets)
#   PRIVACY_PATTERNS='extra|regex'                   optional extra generic regex
#
# This file holds NO identifier. Literals are read from SSM at run time, piped to
# git grep on stdin, and never echoed or written to disk. Hits print only
# <commit>:<file>:<line> (index:<file>:<line> for staged files). Decimal values with
# 3+ decimals (coordinates) are also searched truncated to 2 dp; values with spaces are
# also searched without them.
#
# Fails closed: if SSM returns fewer values than configured, or a value is too short to
# search safely, it refuses to report clean.
#
# Exit codes: 0 clean, 1 hits or a guard / self-test failure, 2 error.
set -euo pipefail

OFFLINE=0
WITH_SECRETS=0
BASE="${PRIVACY_BASE:-}"

usage() { echo "Usage: $0 [--offline] [--with-secrets] [--base SHA]" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --offline) OFFLINE=1 ;;
    --with-secrets) WITH_SECRETS=1 ;;
    --base) [ $# -ge 2 ] || usage; BASE="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "privacy-check: unknown argument: $1" >&2; usage ;;
  esac
  shift
done

# shellcheck source=_lib.sh
. "$(dirname "$0")/_lib.sh"

# Generic shapes: live Stripe-style keys, AWS access key IDs, private key blocks.
# None of these can match its own source text (the character classes don't include
# the brackets they're written with). No \b: some git builds' `git grep -E` silently
# match nothing with it.
GENERIC='sk_live_[A-Za-z0-9]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'
if [ -n "${PRIVACY_PATTERNS:-}" ]; then GENERIC="$GENERIC|$PRIVACY_PATTERNS"; fi

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "privacy-check: not inside a git repository" >&2; exit 2; }
cd "$REPO"

if [ -z "$BASE" ]; then
  BASE=$(git rev-list --max-parents=0 HEAD | tail -1)
fi
git rev-parse --verify --quiet "$BASE^{commit}" >/dev/null || { echo "privacy-check: base commit not found: $BASE" >&2; exit 2; }

# The base commit itself is included (BASE^..HEAD would fail on a root commit).
REVS=("$BASE")
while IFS= read -r rev; do REVS+=("$rev"); done < <(git rev-list "$BASE"..HEAD)

# scan <repo> <generic|literal> [rev...]
#   generic: GENERIC regex.   literal: fixed strings from stdin, case-insensitive.
# Scans the given commits, then the index (git grep --cached).
# Prints only locations. Returns 0 = hits, 1 = clean, 2 = git error.
scan() {
  local repo="$1" mode="$2"; shift 2
  local pats="" out rc any=1 target
  local -a args
  if [ "$mode" = literal ]; then
    pats=$(sed '/^[[:space:]]*$/d')
    [ -n "$pats" ] || return 2   # an empty pattern list would match nothing (or everything)
  fi
  for target in revs index; do
    if [ "$target" = revs ] && [ $# -eq 0 ]; then continue; fi
    if [ "$mode" = generic ]; then args=(-nIE -e "$GENERIC"); else args=(-nIiF -f -); fi
    if [ "$target" = index ]; then args=(--cached "${args[@]}"); fi
    rc=0
    if [ "$target" = revs ]; then
      out=$(printf '%s\n' "$pats" | git -C "$repo" grep "${args[@]}" "$@" -- . 2>/dev/null) || rc=$?
    else
      out=$(printf '%s\n' "$pats" | git -C "$repo" grep "${args[@]}" -- . 2>/dev/null) || rc=$?
    fi
    if [ "$rc" -gt 1 ]; then out=""; pats=""; return 2; fi
    if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
      if [ "$target" = revs ]; then printf '%s\n' "$out" | cut -d: -f1-3
      else printf '%s\n' "$out" | cut -d: -f1-2 | sed 's/^/index:/'; fi
      any=0
    fi
    out=""
  done
  pats=""
  return "$any"
}

# report <label> <rc>: 1 = clean, 0 = hits (exit 1), anything else = error (exit 2)
report() {
  case "$2" in
    1) echo "privacy-check: $1: clean" ;;
    0) echo "privacy-check: $1: HITS (locations above)"; exit 1 ;;
    *) echo "privacy-check: $1: git grep error" >&2; exit 2 ;;
  esac
}

# ---- Step 0: self-test the generic pipeline on a throwaway repo ------------------------
SELFTEST_DIR=$(mktemp -d)
trap 'rm -rf "$SELFTEST_DIR"' EXIT
(
  cd "$SELFTEST_DIR"
  git init -q .
  # Built at run time so this file never contains a matching string.
  printf 'sk_live_%s\n' 1B2C3D4E5F6G > probe.txt
  git add probe.txt
  git -c user.name=privacy-check -c user.email=privacy-check@example.invalid -c commit.gpgsign=false \
    commit -q --no-verify -m probe
) >/dev/null 2>&1 || { echo "privacy-check: self-test setup failed" >&2; exit 2; }
st_rc=0
st_out=$(scan "$SELFTEST_DIR" generic "$(git -C "$SELFTEST_DIR" rev-parse HEAD)" </dev/null) || st_rc=$?
if [ "$st_rc" -ne 0 ] || [ -z "$st_out" ]; then
  echo "privacy-check self-test failed: pattern grep is a no-op on this git"
  exit 1
fi
echo "privacy-check: self-test ok"

# ---- Step 1: generic pattern grep over BASE..HEAD plus the index -----------------------
echo "privacy-check: scanning ${#REVS[@]} commit(s) from ${BASE:0:7} plus the index"
rc=0
scan "$REPO" generic "${REVS[@]}" </dev/null || rc=$?
report "pattern grep" "$rc"

if [ "$OFFLINE" -eq 1 ]; then
  echo "PARTIAL: SSM literal checks NOT run (--offline)."
  exit 0
fi

# ---- Step 2: identifier literals from SSM ----------------------------------------------
# shellcheck disable=SC2206  # word-splitting the configured name lists is intended
SHORT=(${PRIVACY_PARAMS:-})
if [ "$WITH_SECRETS" -eq 1 ]; then
  # shellcheck disable=SC2206
  SHORT+=(${PRIVACY_SECURE_PARAMS:-})
fi
if [ ${#SHORT[@]} -eq 0 ]; then
  echo "privacy-check: PRIVACY_PARAMS is empty; nothing to compare against. Refusing to report clean."
  echo "              Set it in .env, or run with --offline and accept a PARTIAL result."
  exit 1
fi

WANT=${#SHORT[@]}
VALS=""
got=0
# get-parameters takes at most 10 names per call.
i=0
while [ "$i" -lt "$WANT" ]; do
  NAMES=()
  j=$i
  while [ "$j" -lt "$WANT" ] && [ "$j" -lt $((i + 10)) ]; do
    NAMES+=("$PARAM_PREFIX/${SHORT[$j]}"); j=$((j + 1))
  done
  chunk=$(aws ssm get-parameters --region "$REGION" --names "${NAMES[@]}" --with-decryption \
            --query 'Parameters[].Value' --output text 2>/dev/null) \
    || { echo "privacy-check: aws ssm get-parameters failed" >&2; exit 2; }
  [ "$chunk" = "None" ] && chunk=""
  chunk=$(printf '%s' "$chunk" | tr '\t' '\n' | sed '/^[[:space:]]*$/d')
  if [ -n "$chunk" ]; then
    got=$((got + $(printf '%s\n' "$chunk" | grep -c .)))
    VALS="$VALS$chunk"$'\n'
  fi
  chunk=""
  i=$j
done

if [ "$got" -ne "$WANT" ]; then
  VALS=""
  echo "privacy-check: expected $WANT values from SSM, got $got; refusing to report clean"
  exit 1
fi

# Expand variants without echoing anything.
PATS=""
while IFS= read -r v; do
  [ -n "$v" ] || continue
  if [ ${#v} -lt 4 ]; then
    VALS=""; PATS=""
    echo "privacy-check: a configured value is shorter than 4 characters; too short to search safely"
    exit 1
  fi
  PATS="$PATS$v"$'\n'
  case "$v" in *[[:space:]]*) PATS="$PATS$(printf '%s' "$v" | tr -d '[:space:]')"$'\n' ;; esac
  if [[ "$v" =~ ^-?[0-9]+\.[0-9]{3,}$ ]]; then
    PATS="$PATS$(printf '%s' "$v" | sed -E 's/^(-?[0-9]+\.[0-9]{2}).*/\1/')"$'\n'
  fi
done <<< "$VALS"
VALS=""

rc=0
printf '%s' "$PATS" | scan "$REPO" literal "${REVS[@]}" || rc=$?
PATS=""
report "identifier literals ($WANT)" "$rc"

echo "privacy-check: clean"
exit 0
