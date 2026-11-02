#!/bin/bash
# COMMON stage 1 - offline validation, no database: static checks, build, APEXlang validation (SQLcl, no DB).
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

step static static
step build build
step apexlang-validate apexlang
