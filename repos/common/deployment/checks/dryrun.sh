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
unset BASE DB_TESTS PAGES DEPLOY APP_ONLY PATCH_FILES CHANGED_OBJECTS APP_CHANGED STUB_PASSED STUB_DROP STUB_DIFF STUB_UPGRADED START_FROM
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
RECORD=$full_rec START_FROM=4 scenario setup-start-from-4 0 full "3.2b-deploy-decision 3.3-backup-schema 3.3b-drop-old-baseline" -- setup
fresh_rec="${full_rec/ FULL / DIRTY }
PASSED fresh $FINGERPRINT"
RECORD=$fresh_rec scenario setup-job-4-passed-before 0 upgrade "3.2b-deploy-decision 3.3-backup-schema" -- setup
RECORD="${full_rec/ FULL / DIRTY }" START_FROM=5 scenario setup-start-from-5-not-allowed 0 full "3.2b-deploy-decision" -- setup
expect "setup-start-from-5-not-allowed: the reason is noted" grep -q 'not possible' "$W/logs-setup-start-from-5-not-allowed/start-note"
PATCH_FILES=$(awk -v k="$one" '$1 == k {print $3}' "$manifest") CHANGED_OBJECTS=XXFND_DDL_PKG APP_CHANGED=true \
  RECORD=$patch_rec scenario quick-check 0 - "4.Q0-version-guard 4.Q1-mark-record 4.Q2-apply-code 4.Q3-import-app 4.Q4-online-validation 4.Q5-record-version 4.Q6-select-tests 4.Q7-db-tests 4.Q8-record-tests" -- quick
expect "quick-check: only the changed file applied" grep -q '^1 code object file(s) applied' "$W/logs-quick-check/4.Q2-apply-code.log"
expect "quick-check: callers from the live dependencies" grep -q 'XXFND_CALLER_PKG' "$W/logs-quick-check/4.Q6-select-tests.log"
RECORD='' scenario fresh-full 0 - "4.1a-mark-record 4.1-remove-app 4.1b-remove-test-accounts 4.2-deploy-this 4.2b-load-test-data 4.3-online-validation 4.4-dependency-check 4.5-record-fresh-install" -- fresh
expect "fresh-full: every table of the data file merged" grep -q 'row(s) in 85 table(s)' "$W/logs-fresh-full/4.2b-load-test-data.log"
APP_ONLY=true RECORD=$full_rec scenario fresh-app-only 0 - "4.0-version-guard 4.1a-mark-record 4.1-remove-apex-app 4.2-import-app 4.3-online-validation 4.7-record-version" -- fresh
RECORD=$fresh_rec scenario upgrade 0 - "5.0a-mark-record 5.1-remove-app 5.2-build-last 5.2-deploy-last 5.3-load-last-test-data 5.4-snapshot 5.5-upgrade-this 5.6-nothing-lost 5.7-load-this-test-data 5.8-same-as-fresh-install 5.9-online-validation 5.10-drop-snapshot 5.11-record-version" -- upgrade HEAD
expect "upgrade: row counts differ - information only" grep -q 'info: rows in XXFND_A' "$W/logs-upgrade/5.8-same-as-fresh-install.log"
DEPLOY=upgrade RECORD=$fresh_rec scenario upgrade-only 0 - "5.0-version-guard 5.0a-mark-record 5.11-record-version" -- upgrade HEAD
DEPLOY=upgrade RECORD="${full_rec/ FULL / DIRTY }" scenario upgrade-job-4-not-recorded 1 - "" -- upgrade HEAD
STUB_DIFF=1 STUB_UPGRADED=1 RECORD=$fresh_rec scenario upgrade-differs-from-fresh 1 - "5.7-load-this-test-data" -- upgrade HEAD
expect "upgrade-differs-from-fresh: the extra column is named" grep -q 'FAIL only after the upgrade: C XXFND_A.Y' "$W/logs-upgrade-differs-from-fresh/5.8-same-as-fresh-install.log"
RECORD='' scenario upgrade-no-fresh-install 1 - "5.7-load-this-test-data" -- upgrade HEAD
DEPLOY=full RECORD=$full_rec scenario test-full 0 - "6.0a-version-guard 6.0-select-tests 6.2-db-tests 6.2b-record-tests 6.4-apex-sert 6.5-dbsat" -- test
DEPLOY=full STUB_DROP=1 RECORD=$full_rec scenario test-session-ended-early 1 - "6.0-select-tests 6.2b-record-tests" -- test
expect "test-session-ended-early: reported" grep -q 'did not run' "$W/logs-test-session-ended-early/6.2-db-tests.log"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario test-reuse-scans-passed 0 - "6.0-select-tests 6.2-db-tests 6.4-apex-sert 6.5-dbsat" -- test
expect "test-reuse-scans-passed: SERT not repeated" grep -q 'not run again' "$W/logs-test-reuse-scans-passed/6.4-apex-sert.log"
expect "test-reuse-scans-passed: nothing changed - fixtures only" grep -qx 'NONE' "$W/logs-test-reuse-scans-passed/db-tests"
expect "test-full: every test file ran, none dropped" \
  test "$(grep -c . "$W/logs-test-full/tests-expected")" -gt 10 -a "$(grep -c . "$W/logs-test-full/tests-ran")" = "$(grep -c . "$W/logs-test-full/tests-expected")"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario ui-reuse-passed 0 - "6.3-browser-tests" -- ui
RECORD=$full_rec scenario finalize 0 - "7.0-version-guard 7.1-export" -- finalize "$W/out"
DEPLOY=full RECORD="${full_rec/$FINGERPRINT/otherversion}" scenario test-another-version-deployed 1 - "" -- test
expect "test-another-version-deployed: stops before the tests" test ! -f "$W/logs-test-another-version-deployed/6.2-db-tests.log"
exit "$rc"
