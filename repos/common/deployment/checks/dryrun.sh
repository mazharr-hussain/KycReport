#!/bin/bash
# Dry run of the database jobs (step 1.1, also pipeline-check.yml): db/run.sh runs every path of jobs 3-7 against a
# stand-in for SQLcl (checks/sqlcl-stub.sh - no database) on a built copy of the repository, and each scenario's
# decision, steps and result are compared with what they must be. A pipeline change that breaks a path fails here,
# before any run on GitHub. Usage: dryrun.sh (from anywhere); exit 1 when a scenario is wrong.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
W=$(mktemp -d); trap 'git -C "$W/repo" worktree prune 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/repo"; cp -r "$ROOT/repos" "$W/repo/"
R=$W/repo/repos/common/deployment
( cd "$W/repo" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm dry ) || exit 1
bash "$W/repo/repos/common/build.sh" > "$W/build.log" 2>&1 || { cat "$W/build.log"; exit 1; }
eval "$(python3 "$R/checks/fingerprint.py" "$W/repo" | sed 's/^\([a-z_]*\)=/export \U\1=/')"
manifest=$W/repo/repos/common/db/deploy/code-manifest.txt
export SQL=$HERE/sqlcl-stub.sh WALLET=/dev/null VAL_DB_SERVICE=svc_high ADMIN_PW=x XXCUS_PW=x GITHUB_STEP_SUMMARY=
HEAD_SHA=$(git -C "$W/repo" rev-parse HEAD)
export RUNNER_TEMP=$W/runner HEAD_SHA; mkdir -p "$RUNNER_TEMP"
unset BASE DB_TESTS PAGES DEPLOY APP_ONLY PATCH_FILES CHANGED_OBJECTS APP_CHANGED STUB_PASSED STUB_DROP REFRESH_BASELINE
code() { awk '{print "CODE " $1 " " $2}' "$manifest"; }
rc=0
expect() { local name=$1; shift; if "$@"; then echo "PASS $name"; else echo "FAIL $name"; rc=1; fi; }
# scenario <name> <expected exit> <expected deploy or -> <steps that must pass, space separated> -- <run.sh args>
scenario() {
  local name=$1 want_rc=$2 want_deploy=$3 steps=$4 got s out; shift 5
  export STUB_DIR=$W/stub-$name STUB_LOG=$W/stub-$name/calls LOG_DIR=$W/logs-$name REPORT_DIR=$W/rep-$name
  mkdir -p "$STUB_DIR" "$LOG_DIR"; [ -n "${RECORD:-}" ] && printf '%s\n' "$RECORD" > "$STUB_DIR/record"
  [ -n "${SEED:-}" ] && cp "$SEED"/* "$LOG_DIR/"
  out=$(cd "$W/repo" && bash "$R/db/run.sh" "$@" 2>&1); got=$?
  local bad=""
  [ "$got" = "$want_rc" ] || bad="exit $got (expected $want_rc)"
  if [ "$want_deploy" != - ] && [ "$(cat "$LOG_DIR/deploy" 2>/dev/null)" != "$want_deploy" ]; then
    bad="$bad deploy=$(cat "$LOG_DIR/deploy" 2>/dev/null) (expected $want_deploy)"
  fi
  for s in $steps; do echo "$out" | grep -q "^PASS $s " || bad="$bad step $s did not pass"; done
  if [ -z "$bad" ]; then echo "PASS $name"; else echo "FAIL $name:$bad"; echo "$out" | tail -25 | sed 's/^/    /'; rc=1; fi
}
full_rec="DEPLOYED $FINGERPRINT $DB_FINGERPRINT $STRUCT_FINGERPRINT $APP_FINGERPRINT FULL $HEAD_SHA
$(code)"
one=$(awk '/^package-body-/ {print $1; exit}' "$manifest")
patch_rec="DEPLOYED old old $STRUCT_FINGERPRINT $APP_FINGERPRINT FULL $HEAD_SHA
$(code | awk -v k="$one" '$2 == k {$3 = "oldhash"} {print}')"

RECORD='' scenario setup-nothing-recorded 0 full "3.2b-deploy-decision 3.3-backup-schema 3.4-apex-sert" -- setup
RECORD=$full_rec scenario setup-same-version 0 reuse "3.2b-deploy-decision 3.4-apex-sert" -- setup
RECORD="DEPLOYED other $DB_FINGERPRINT $STRUCT_FINGERPRINT other FULL -
$(code)" scenario setup-same-db-scripts 0 app "3.2b-deploy-decision" -- setup
RECORD=$patch_rec scenario setup-one-package-changed 0 patch "3.2b-deploy-decision 3.3-backup-schema" -- setup
expect "setup-one-package-changed: patch file" [ "$(cat "$W/logs-setup-one-package-changed/patch-files" 2>/dev/null)" = "$(awk -v k="$one" '$1 == k {print $3}' "$manifest")" ]
RECORD="${full_rec/ FULL / DIRTY }" scenario setup-deploy-not-finished 0 full "3.2b-deploy-decision" -- setup
RECORD=$full_rec REFRESH_BASELINE=true scenario setup-refresh-baseline 0 full "3.2b-deploy-decision" -- setup
PATCH_FILES=$(awk -v k="$one" '$1 == k {print $3}' "$manifest") CHANGED_OBJECTS=XXFND_DDL_PKG APP_CHANGED=true \
  RECORD=$patch_rec scenario quick-check 0 - "4.Q1-mark-record 4.Q2-apply-code 4.Q3-import-app 4.Q4-online-validation 4.Q5-record-version 4.Q6-select-tests 4.Q7-db-tests 4.Q8-record-tests" -- quick
expect "quick-check: only the changed file applied" grep -q '^1 code object file(s) applied' "$W/logs-quick-check/4.Q2-apply-code.log"
expect "quick-check: callers from the live dependencies" grep -q 'XXFND_CALLER_PKG' "$W/logs-quick-check/4.Q6-select-tests.log"
RECORD='' scenario fresh-full 0 - "4.0-baseline 4.1a-mark-record 4.1-remove-app 4.1b-remove-test-accounts 4.2-deploy-this 4.3-online-validation 4.4-dependency-check" -- fresh
APP_ONLY=true RECORD=$full_rec scenario fresh-app-only 0 - "4.1a-mark-record 4.1-remove-apex-app 4.2-import-app 4.3-online-validation 4.7-record-version" -- fresh
RECORD='' scenario upgrade 0 - "5.1-remove-app 5.2-build-last 5.2-deploy-last 5.3-restore-data 5.4-upgrade-this 5.5-nothing-lost 5.6-online-validation 5.7-drop-backup-schema 5.8-record-version" -- upgrade HEAD
DEPLOY=full RECORD=$full_rec scenario test-full 0 - "6.0-select-tests 6.2-db-tests 6.2b-record-tests 6.4-apex-sert 6.5-dbsat" -- test
DEPLOY=full STUB_DROP=1 RECORD=$full_rec scenario test-session-ended-early 1 - "6.0-select-tests 6.2b-record-tests" -- test
expect "test-session-ended-early: reported" grep -q 'did not run' "$W/logs-test-session-ended-early/6.2-db-tests.log"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario test-reuse-scans-passed 0 - "6.0-select-tests 6.2-db-tests 6.4-apex-sert 6.5-dbsat" -- test
expect "test-reuse-scans-passed: SERT not repeated" grep -q 'not run again' "$W/logs-test-reuse-scans-passed/6.4-apex-sert.log"
expect "test-reuse-scans-passed: nothing changed - fixtures only" grep -qx 'NONE' "$W/logs-test-reuse-scans-passed/db-tests"
expect "test-full: every test file ran, none dropped" \
  test "$(grep -c . "$W/logs-test-full/tests-expected")" -gt 10 -a "$(grep -c . "$W/logs-test-full/tests-ran")" = "$(grep -c . "$W/logs-test-full/tests-expected")"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario ui-reuse-passed 0 - "6.3-browser-tests" -- ui
scenario finalize 0 - "7.1-export" -- finalize "$W/out"
exit "$rc"
