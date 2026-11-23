#!/bin/bash
# Dry run of the database jobs (step 1.1): db/run.sh runs every path of jobs 3-9 against a
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
export FULL_VALIDATION=true DB_TARGET=dev SQL=$HERE/sqlcl-stub.sh WALLET=/dev/null VAL_DB_SERVICE=svc_high ADMIN_PW=x XXCUS_PW=x GITHUB_STEP_SUMMARY=
HEAD_SHA=$(git -C "$W/repo" rev-parse HEAD)
export RUNNER_TEMP=$W/runner HEAD_SHA; mkdir -p "$RUNNER_TEMP"
unset DB_CHANGED BASE DB_TESTS PAGES DEPLOY APP_ONLY PATCH_FILES CHANGED_OBJECTS APP_CHANGED STUB_PASSED STUB_DROP STUB_DIFF STUB_UPGRADED START_FROM RESUME_AT
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

RECORD='' scenario setup-nothing-recorded 0 full "3.2b-deploy-decision 3.3b-drop-old-backups 3.4-apex-sert" -- setup
RECORD=$full_rec scenario setup-same-version 0 reuse "3.2b-deploy-decision 3.4-apex-sert" -- setup
RECORD="DEPLOYED other $DB_FINGERPRINT $STRUCT_FINGERPRINT other FULL -
$(code)" scenario setup-same-db-scripts 0 app "3.2b-deploy-decision" -- setup
RECORD=$patch_rec scenario setup-one-package-changed 0 patch "3.2b-deploy-decision 3.3b-drop-old-backups" -- setup
expect "setup-one-package-changed: patch file" [ "$(cat "$W/logs-setup-one-package-changed/patch-files" 2>/dev/null)" = "$(awk -v k="$one" '$1 == k {print $3}' "$manifest")" ]
RECORD="${full_rec/ FULL / DIRTY }" scenario setup-deploy-not-finished 0 full "3.2b-deploy-decision" -- setup
RECORD=$full_rec START_FROM=5 scenario setup-start-from-5 0 full "3.2b-deploy-decision 3.3b-drop-old-backups" -- setup
fresh_rec="${full_rec/ FULL / DIRTY }
PASSED fresh $FINGERPRINT"
RECORD=$fresh_rec scenario setup-job-4-passed-before 0 upgrade "3.2b-deploy-decision 3.3b-drop-old-backups" -- setup
RECORD="${full_rec/ FULL / DIRTY }" START_FROM=6 scenario setup-start-from-6-not-allowed 0 full "3.2b-deploy-decision" -- setup
expect "setup-start-from-6-not-allowed: the reason is noted" grep -q 'not possible' "$W/logs-setup-start-from-6-not-allowed/start-note"
PATCH_FILES=$(awk -v k="$one" '$1 == k {print $3}' "$manifest") CHANGED_OBJECTS=XXFND_DDL_PKG APP_CHANGED=true \
  RECORD=$patch_rec scenario quick-check 0 - "4.Q0-version-guard 4.Q1-mark-record 4.Q2-apply-code 4.Q3-import-app 4.Q4-online-validation 4.Q5-record-version 4.Q6-select-tests 4.Q7-db-tests 4.Q8-record-tests" -- quick
expect "quick-check: only the changed file applied" grep -q '^1 code object file(s) applied' "$W/logs-quick-check/4.Q2-apply-code.log"
expect "quick-check: callers from the live dependencies" grep -q 'XXFND_CALLER_PKG' "$W/logs-quick-check/4.Q6-select-tests.log"
RECORD='' scenario fresh-full 0 - "5.1a-mark-record 5.1-remove-app 5.1b-remove-test-accounts 5.2-deploy-this 5.2a-record-install 5.2b-load-test-data 5.2c-data-loaded 5.3-online-validation 5.4-dependency-check 5.5-record-fresh-install" -- fresh
expect "fresh-full: every table of the data file merged" grep -q ' row(s) in [0-9]* table(s)' "$W/logs-fresh-full/5.2b-load-test-data.log"
inst_rec="${full_rec/ FULL / DIRTY }
PASSED install $INSTALL_FINGERPRINT"
RECORD=$inst_rec scenario setup-data-only 0 data "3.2b-deploy-decision 3.3b-drop-old-backups" -- setup
DEPLOY=data RECORD=$inst_rec scenario fresh-data-only 0 - "5.0-install-guard 5.2b-load-test-data 5.2c-data-loaded 5.3-online-validation 5.4-dependency-check 5.5-record-fresh-install" -- fresh
expect "fresh-data-only: no redeploy" bash -c "! grep -q '5.2-deploy-this\\|5.1-remove-app' '$W/logs-fresh-data-only/steps' 2>/dev/null && ! ls '$W/logs-fresh-data-only' | grep -q '5.2-deploy-this'"
DEPLOY=data RECORD="${full_rec/ FULL / DIRTY }" scenario fresh-data-only-not-installed 1 - "" -- fresh
DB_TARGET=test RECORD='' scenario fresh-test-db-no-test-data 1 - "5.2-deploy-this" -- fresh
expect "fresh-test-db-no-test-data: refused" grep -q 'test data loads only into the dev database' "$W/logs-fresh-test-db-no-test-data/5.2b-load-test-data.log"
FULL_VALIDATION=false RECORD='' scenario setup-draft-no-sert 0 full "3.4-apex-sert" -- setup
expect "setup-draft-no-sert: APEX-SERT skipped" grep -q 'full validation only' "$W/logs-setup-draft-no-sert/3.4-apex-sert.log"
FULL_VALIDATION=false DEPLOY=full RECORD=$full_rec scenario test-draft-no-scans 0 - "7.4-apex-sert 7.5-dbsat" -- test
expect "test-draft-no-scans: DBSAT skipped" grep -q 'full validation only' "$W/logs-test-draft-no-scans/7.5-dbsat.log"
DB_CHANGED=false RECORD='' scenario fresh-db-unchanged 0 - "5.1a-mark-record 5.1-remove-app 5.1b-remove-test-accounts 5.2-deploy-this 5.2a-record-install 5.2b-load-test-data 5.2c-data-loaded 5.3-online-validation 5.4-dependency-check 5.5-record-fresh-install 5.7-record-version" -- fresh
expect "fresh-full: changed DB scripts - no 5.7 (job 6 records the version)" bash -c "! ls '$W/logs-fresh-full' | grep -q '5.7-record-version'"
loaded_rec="${full_rec/ FULL / DIRTY }
PASSED loaded $FINGERPRINT"
RECORD=$loaded_rec scenario setup-loaded 0 loaded "3.2b-deploy-decision 3.3b-drop-old-backups" -- setup
DEPLOY=loaded RECORD=$loaded_rec scenario fresh-loaded 0 - "5.0-loaded-guard 5.3-online-validation 5.4-dependency-check 5.5-record-fresh-install" -- fresh
expect "fresh-loaded: no remove, redeploy or data reload" bash -c "! ls '$W/logs-fresh-loaded' | grep -qE '5.1-remove-app|5.2-deploy-this|5.2b-load-test-data'"
DEPLOY=loaded RECORD="${full_rec/ FULL / DIRTY }" scenario fresh-loaded-not-held 1 - "" -- fresh
# I-078: resume at the failed step - the steps before RESUME_AT are skipped, a failure keeps the ones that passed
DEPLOY=loaded RESUME_AT=5.5-record-fresh-install RECORD=$loaded_rec scenario fresh-resume-at-5.5 0 - "5.0-loaded-guard 5.3-online-validation 5.4-dependency-check 5.5-record-fresh-install" -- fresh
expect "fresh-resume-at-5.5: 5.3 and 5.4 not run again" grep -q 'resumes at 5.5' "$W/logs-fresh-resume-at-5.5/5.4-dependency-check.log"
expect "fresh-resume-at-5.5: 5.5 runs" bash -c "! grep -q 'resumes at' '$W/logs-fresh-resume-at-5.5/5.5-record-fresh-install.log'"
APP_ONLY=true RECORD=$full_rec scenario fresh-app-only 0 - "5.0-version-guard 5.1a-mark-record 5.1-remove-apex-app 5.2-import-app 5.3-online-validation 5.7-record-version" -- fresh
RECORD=$fresh_rec scenario upgrade 0 - "6.0a-mark-record 6.1-remove-app 6.2-build-last 6.2-deploy-last 6.3-load-last-test-data 6.4-snapshot 6.5-upgrade-this 6.6-nothing-lost 6.7-load-this-test-data 6.8-same-as-fresh-install 6.9-online-validation 6.11-record-version" -- upgrade HEAD
expect "upgrade: row counts differ - information only" grep -q 'info: rows in XXFND_A' "$W/logs-upgrade/6.8-same-as-fresh-install.log"
DEPLOY=upgrade RECORD=$fresh_rec scenario upgrade-only 0 - "6.0-version-guard 6.0a-mark-record 6.11-record-version" -- upgrade HEAD
DEPLOY=upgrade RECORD="${full_rec/ FULL / DIRTY }" scenario upgrade-job-4-not-recorded 1 - "" -- upgrade HEAD
upgraded_rec="${full_rec/ FULL / DIRTY }
PASSED fresh $FINGERPRINT
PASSED upgraded $FINGERPRINT"
RECORD=$upgraded_rec scenario setup-upgraded 0 upgraded "3.2b-deploy-decision" -- setup
DEPLOY=upgraded RECORD=$upgraded_rec scenario upgrade-resumed 0 - "6.0-upgraded-guard 6.6-nothing-lost 6.7-load-this-test-data 6.8-same-as-fresh-install 6.9-online-validation 6.11-record-version" -- upgrade HEAD
expect "upgrade-resumed: the snapshot before the upgrade read from the database" grep -q 'read from the database' "$W/logs-upgrade-resumed/6.6-nothing-lost.log"
expect "upgrade-resumed: no reinstall, no second upgrade" bash -c "! ls '$W/logs-upgrade-resumed' | grep -qE '6.1-remove-app|6.2-deploy-last|6.5-upgrade-this'"
DEPLOY=upgraded RECORD="${full_rec/ FULL / DIRTY }" scenario upgrade-resumed-not-held 1 - "" -- upgrade HEAD
DEPLOY=upgraded RESUME_AT=6.8-same-as-fresh-install RECORD=$upgraded_rec scenario upgrade-resume-at-6.8 0 - "6.0-upgraded-guard 6.6-nothing-lost 6.7-load-this-test-data 6.8-same-as-fresh-install 6.9-online-validation 6.11-record-version" -- upgrade HEAD
expect "upgrade-resume-at-6.8: 6.7 not run again" grep -q 'resumes at 6.8' "$W/logs-upgrade-resume-at-6.8/6.7-load-this-test-data.log"
STUB_DIFF=1 STUB_UPGRADED=1 DEPLOY=upgraded RECORD=$upgraded_rec scenario upgrade-resume-keeps-passed 1 - "6.6-nothing-lost 6.7-load-this-test-data" -- upgrade HEAD
expect "upgrade-resume-keeps-passed: 6.6 and 6.7 kept for the next run" grep -q "step:6.7-load-this-test-data" "$W/stub-upgrade-resume-keeps-passed/sql-bodies"
STUB_DIFF=1 STUB_UPGRADED=1 RECORD=$fresh_rec scenario upgrade-differs-from-fresh 1 - "6.7-load-this-test-data" -- upgrade HEAD
expect "upgrade-differs-from-fresh: the extra column is named" grep -q 'FAIL only after the upgrade: C XXFND_A.Y' "$W/logs-upgrade-differs-from-fresh/6.8-same-as-fresh-install.log"
RECORD='' scenario upgrade-no-fresh-install 1 - "6.7-load-this-test-data" -- upgrade HEAD
DEPLOY=full RECORD=$full_rec scenario test-full 0 - "7.0a-version-guard 7.0-select-tests 7.2-db-tests 7.2b-record-tests 7.4-apex-sert 7.5-dbsat" -- test
DEPLOY=full STUB_DROP=1 RECORD=$full_rec scenario test-session-ended-early 1 - "7.0-select-tests 7.2b-record-tests" -- test
expect "test-session-ended-early: reported" grep -q 'did not run' "$W/logs-test-session-ended-early/7.2-db-tests.log"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario test-reuse-scans-passed 0 - "7.0-select-tests 7.2-db-tests 7.4-apex-sert 7.5-dbsat" -- test
expect "test-reuse-scans-passed: SERT not repeated" grep -q 'not run again' "$W/logs-test-reuse-scans-passed/7.4-apex-sert.log"
expect "test-reuse-scans-passed: nothing changed - fixtures only" grep -qx 'NONE' "$W/logs-test-reuse-scans-passed/db-tests"
expect "test-full: every test file ran, none dropped" \
  test "$(grep -c . "$W/logs-test-full/tests-expected")" -gt 10 -a "$(grep -c . "$W/logs-test-full/tests-ran")" = "$(grep -c . "$W/logs-test-full/tests-expected")"
DEPLOY=reuse STUB_PASSED=1 RECORD=$full_rec scenario ui-reuse-passed 0 - "8.3-browser-tests" -- ui
RECORD=$full_rec scenario finalize 0 - "9.0-version-guard 9.1-export" -- finalize "$W/out"
DEPLOY=retest RECORD="${full_rec/$FINGERPRINT/oldversion}
FAILED repos/common/tests/r79_security_test.sql" scenario test-retest 0 - "7.0a-version-guard 7.1-load-test-data 7.1b-test-prerequisites 7.0-select-tests 7.2-db-tests 7.2b-record-tests 7.3-record-version" -- test
expect "test-retest: only the failed file" grep -qx "repos/common/tests/r79_security_test.sql " "$W/logs-test-retest/db-tests"
DEPLOY=retest RECORD="${full_rec/ FULL / DIRTY }" scenario test-retest-not-verified 1 - "" -- test
DEPLOY=full RECORD="${full_rec/$FINGERPRINT/otherversion}" scenario test-another-version-deployed 1 - "" -- test
expect "test-another-version-deployed: stops before the tests" test ! -f "$W/logs-test-another-version-deployed/7.2-db-tests.log"
exit "$rc"
