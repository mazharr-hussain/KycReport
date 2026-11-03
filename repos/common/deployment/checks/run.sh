#!/bin/bash
# COMMON pipeline job 1 - offline validation, no OCI and no database:
#   1.0a PR title "<APP> Release <N>: <summary>" and its linked issues ("Fixes #n") - pr_meta.py
#   1.0 secret scan of the PR's commits (gitleaks)
#   1.1 pipeline lint (actionlint on the workflows, shellcheck on the pipeline scripts, the decision self-test and
#       the dry run of every database-job path against a SQLcl stand-in - checks/dryrun.sh)   1.1b SOURCE-MAP in step
#   1.2 static checks (pr_checks.py)          1.3 requirements check (warning only)
#   1.4 build                                  1.5 APEXlang source checks (LF line endings) + validation (SQLcl, no DB)
#   1.6 PMD (PL/SQL rules, warnings only)
# Usage: run.sh [lint]   (lint: only 1.1, for pipeline-check.yml; env: SQL = SQLcl binary; PMD = PMD launcher; GITLEAKS = gitleaks binary; BASE = base commit and
#                 BODY = PR body file, optional; PR_TITLE, PR_BODY, GITHUB_TOKEN, GITHUB_REPOSITORY for 1.0a; RELEASE = release number, optional)
# A failing step stops the job and is recorded for the error-handling job (lib/step.sh).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=SCRIPTDIR/../lib/step.sh
. "$HERE/../lib/step.sh"

pr_meta() {        # pull requests only: title format, linked issues exist and carry the app's label
  if [ -z "${PR_TITLE:-}" ]; then echo "not a pull request - nothing to check"; return 0; fi
  python3 "$HERE/pr_meta.py"
}
secrets_scan() {   # the pull request's commits (or the last commit of a manual run); a finding fails the job
  local range=${BASE:+$BASE..HEAD}
  "${GITLEAKS:?GITLEAKS is not set}" git --no-banner --redact --exit-code 1 --log-opts="${range:--1}" \
    --report-format json --report-path "$LOG_DIR/gitleaks-report.json" "$ROOT"
}
lint() {   # workflows, the pipeline's composite actions (their shell steps) and scripts: no finding of any level
  local f tmp rc=0
  local wf
  for wf in pipeline release generated-files issues-sync cleanup-runs pipeline-check supersede; do
    actionlint -no-color "$ROOT/.github/workflows/$wf.yml" || rc=1
  done
  find "$ROOT/repos/common/deployment" -name '*.py' -print0 | xargs -0 python3 -m py_compile || rc=1
  python3 "$HERE/selftest.py" || rc=1   # the pipeline's decision logic (affected.py, fingerprint.py, db/decide.py)
  bash "$HERE/dryrun.sh" || rc=1        # every path of the database jobs, without a database
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
source_map() { python3 "$HERE/source_map.py"; }   # new / removed application files registered for the build
# the release number (from the PR title) is stamped into the application ("Release N"); the generated files (db/deploy,
# dependency map, technical docs) of this build are what jobs 4-5 deploy, and are committed to main after the merge
build() { bash "$ROOT/repos/common/build.sh" ${RELEASE:+--release "$RELEASE"}; }
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

if [ "${1:-}" = lint ]; then   # pipeline-check.yml: a pipeline-only push to main
  step 1.1-pipeline-lint lint; exit $?
fi
step 1.0a-pr-title-and-issues pr_meta
step 1.0-secret-scan secrets_scan
step 1.1-pipeline-lint lint
step 1.1b-source-map source_map
step 1.2-static static
step 1.3-docs-check docs
step 1.4-build build
step 1.5-apexlang-validate apexlang
step 1.6-pmd pmd
