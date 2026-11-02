#!/bin/bash
# COMMON pipeline job 3 - offline validation, no OCI and no database:
#   3.1 pipeline lint (actionlint on the workflows, shellcheck on the pipeline scripts)
#   3.2 static checks (pr_checks.py)          3.3 requirements check (warning only)
#   3.4 build                                  3.5 APEXlang source checks (LF line endings) + validation (SQLcl, no DB)
#   3.6 PMD (PL/SQL rules, warnings only)
# Usage: run.sh   (env: SQL = SQLcl binary; PMD = PMD launcher; BASE = base commit and BODY = PR body file, optional)
# A failing step stops the job and is recorded for the error-handling job (lib/step.sh).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=SCRIPTDIR/../lib/step.sh
. "$HERE/../lib/step.sh"

lint() {   # workflows, the pipeline's composite actions (their shell steps) and scripts: no finding of any level
  local f tmp rc=0
  actionlint -no-color "$ROOT"/.github/workflows/pipeline.yml "$ROOT"/.github/workflows/release.yml || rc=1
  for f in "$ROOT"/.github/actions/*/action.yml; do
    tmp=$(mktemp --suffix .sh)
    python3 -c 'import sys, yaml
print("#!/bin/bash")
for s in yaml.safe_load(open(sys.argv[1]))["runs"]["steps"]:
    print(s.get("run", ""))' "$f" > "$tmp"
    if ! shellcheck "$tmp"; then echo "in $f"; rc=1; fi
    rm -f "$tmp"
  done
  find "$ROOT/repos/common/deployment" "$ROOT/repos/common/build.sh" -name '*.sh' -print0 | xargs -0 shellcheck -x || rc=1
  return "$rc"
}
static() {
  local args=()
  [ -n "${BASE:-}" ] && args+=(--base "$BASE")
  [ -n "${BODY:-}" ] && args+=(--body-file "$BODY")
  python3 "$HERE/pr_checks.py" "${args[@]}"
}
docs() {   # warning only: a COMMON feature changed without its requirements.md ("no-req-change" in the PR body skips)
  [ -n "${BASE:-}" ] || return 0
  [ -n "${BODY:-}" ] && grep -qi 'no-req-change' "$BODY" && return 0
  local changed f
  changed=$(git -C "$ROOT" diff --name-only "$BASE" HEAD)
  for f in $(printf '%s\n' "$changed" | sed -n 's#^repos/common/features/\([^/]*\)/.*#\1#p' | sort -u); do
    printf '%s\n' "$changed" | grep -q "^repos/common/docs/components/$f/requirements.md$" \
      || echo "::warning::common/$f changed but repos/common/docs/components/$f/requirements.md did not"
  done
}
build() { bash "$ROOT/repos/common/build.sh"; }
apexlang() {
  local crlf out
  # APEXlang runtime gate: every .apx file must use LF line endings before validate / import
  crlf=$(grep -rlI $'\r' --include='*.apx' "$ROOT/repos/common/dist/app" || true)
  if [ -n "$crlf" ]; then
    echo "APEXLANG_LF_LINE_ENDINGS_REQUIRED_001 - CR line endings in:"; echo "$crlf"; return 1
  fi
  out=$(printf 'apex validate -input %s\nexit\n' "$ROOT/repos/common/dist/app" | "$SQL" -S /nolog 2>&1); echo "$out"
  echo "$out" | grep -q "Validation successful"
}
pmd() { bash "$HERE/pmd.sh"; }

step 3.1-pipeline-lint lint
step 3.2-static static
step 3.3-docs-check docs
step 3.4-build build
step 3.5-apexlang-validate apexlang
step 3.6-pmd pmd
