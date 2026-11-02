#!/bin/bash
# COMMON stage 1 - offline validation, no database: static checks, requirements check (warning), build, APEXlang
# validation (SQLcl, no DB).
# Usage: run.sh   (env: SQL = SQLcl binary; BASE = base commit and BODY = PR body file, both optional)
# A failing step stops the run and is recorded for the pipeline's issue (lib/step.sh).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/../../../.." && pwd)
. "$HERE/../lib/step.sh"

static() { python3 "$HERE/pr_checks.py" ${BASE:+--base "$BASE"} ${BODY:+--body-file "$BODY"}; }
build() { sh "$ROOT/repos/common/build.sh"; }
apexlang() {
  out=$(printf 'apex validate -input %s\nexit\n' "$ROOT/repos/common/dist/app" | "$SQL" -S /nolog 2>&1); echo "$out"
  echo "$out" | grep -q "Validation successful"
}

docs() {   # warning only: a COMMON feature changed without its requirements.md ("no-req-change" in the PR body skips)
  [ -n "${BASE:-}" ] || return 0
  [ -n "${BODY:-}" ] && grep -qi 'no-req-change' "$BODY" && return 0
  changed=$(git -C "$ROOT" diff --name-only "$BASE" HEAD)
  for f in $(printf '%s\n' "$changed" | sed -n 's#^repos/common/features/\([^/]*\)/.*#\1#p' | sort -u); do
    printf '%s\n' "$changed" | grep -q "^repos/common/docs/components/$f/requirements.md$" \
      || echo "::warning::common/$f changed but repos/common/docs/components/$f/requirements.md did not"
  done
}

step static static
step docs-check docs
step build build
step apexlang-validate apexlang
