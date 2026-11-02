#!/bin/bash
# COMMON pipeline - the database jobs on the validation ADB (environment "Oracle DB Dev"). One call per pipeline job:
#   run.sh setup               5   DB setup: 5.1 start the DB (placeholder), 5.2 bootstrap only when needed,
#                                  5.3 backup schema (dropped if it exists, then created)
#   run.sh fresh               6   Deploy fresh app: 6.0 back up the app's data, 6.1 remove app + DB objects,
#                                  6.2 deploy this version, 6.3 online validation
#   run.sh upgrade <base-ref>  7   Upgrade app: 7.1 remove (= 6.1), 7.2 deploy the last release (= 6.2), 7.3 restore
#                                  the data + snapshot, 7.4 upgrade to this version, 7.5 nothing lost,
#                                  7.6 online validation (= 6.3), 7.7 drop the backup schema
#   run.sh test                8   Testing: test users, DB tests (any FAIL or error stops the pipeline)
#   run.sh export <dir>        9.1 APEXlang export of the tested application into <dir>
# This version's application must already be built in repos/common/dist/app (pipeline job 3).
# Env: SQL, WALLET, VAL_DB_SERVICE, ADMIN_PW (pipeline user password per job, 5.2, 8.1), XXCUS_PW (5.2 only), LOG_DIR,
#      BASE (pull request base commit, to see whether bootstrap.sql changed).
# A failing step stops the job (lib/step.sh); the error-handling job reports it on the pull request.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=SCRIPTDIR/../app.env
. "$HERE/../app.env"
# shellcheck source=SCRIPTDIR/../lib/step.sh
. "$HERE/../lib/step.sh"
export CI_USER
THIS=$ROOT/repos/common
LAST=${RUNNER_TEMP:-/tmp}/common-last

S() { bash "$HERE/../lib/sql.sh" "$@"; }

# ---- 5 DB setup ------------------------------------------------------------------------------------------------------
start_db() {   # 5.1 placeholder: the OCI start call comes with job 4 (OCI setup); the validation ADB must be up
  echo "5.1 placeholder - the validation database is expected to be running"
}
bootstrap() {  # 5.2 only when the environment is missing or bootstrap.sql changed in this pull request
  local out reason=""
  if [ -n "${BASE:-}" ] && ! git -C "$ROOT" diff --quiet "$BASE" HEAD -- repos/common/deployment/db/bootstrap.sql; then
    reason="bootstrap.sql changed in this pull request"
  elif ! out=$(S CI "$HERE/needs-bootstrap.sql" check app_schema="$APP_SCHEMA" workspace="$WORKSPACE"); then
    reason="the pipeline user cannot sign in or check the environment"
  elif echo "$out" | grep -q '^BOOTSTRAP NEEDED'; then
    reason=$(echo "$out" | grep '^BOOTSTRAP NEEDED' | tr '\n' ' ')
  fi
  if [ -z "$reason" ]; then
    echo "environment complete - bootstrap not needed"
    return 0
  fi
  echo "bootstrap: $reason"
  S ADMIN "$HERE/bootstrap.sql" check ci_user="$CI_USER" ci_pw="$CI_PW" xxcus_pw="${XXCUS_PW:?XXCUS_PW is not set}"
}
backup_schema() {  # 5.3 (drop_only=N) and 7.7 (drop_only=Y)
  S CI "$HERE/backup-schema.sql" check bkp_schema="$BKP_SCHEMA" ci_user="$CI_USER" drop_only="$1"
}

# ---- shared by 6 and 7 -----------------------------------------------------------------------------------------------
backup() {     # 6.0 and the 7.3 snapshot: the app's data into the backup schema
  S "$APP_SCHEMA" "$HERE/grant-to.sql" check grantee="$BKP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/backup.sql" check app_schema="$APP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/grant-to.sql" check grantee="$APP_SCHEMA"
}
remove_app() { # 6.1 / 7.1
  S CI "$HERE/remove-app.sql" check app_id="$APP_ID" && S "$APP_SCHEMA" "$HERE/clear-schema.sql" check
}
deploy() {     # 6.2 / 7.2 / 7.4: deploy <project dir> install|upgrade - DB scripts, then APEXlang validate + import
  local dir=$1 mode=$2 f out rc
  S "$APP_SCHEMA" "$dir/db/deploy/$mode/run-all.sql" check || return 1
  f=$(mktemp --suffix .sql)
  # validate and import in the same SQLcl session (APEXlang runtime gate)
  printf 'apex validate -input %s\napex import -input %s\n' "$dir/dist/app" "$dir/dist/app" > "$f"
  out=$(S "$APP_SCHEMA" "$f"); rc=$?; rm -f "$f"; echo "$out"
  [ "$rc" -eq 0 ] && echo "$out" | grep -q "Validation successful" && echo "$out" | grep -q "Import successful"
}
validate_online() {  # 6.3 / 7.6
  local pages
  pages=$(find "$THIS/dist/app/pages" -name '*.apx' | wc -l)
  S "$APP_SCHEMA" "$HERE/validate-online.sql" check app_id="$APP_ID" expected_pages="$pages"
}

# ---- 7 only ----------------------------------------------------------------------------------------------------------
build_last() {  # the last release = the pull request's base commit, built the same way
  rm -rf "$LAST"; git -C "$ROOT" worktree prune
  git -C "$ROOT" worktree add -q "$LAST" "$1" && bash "$LAST/repos/common/build.sh" > /dev/null
}
restore() {     # 7.3: data back into the old release, then the snapshot the upgrade is compared with
  S "$APP_SCHEMA" "$HERE/restore.sql" check bkp_schema="$BKP_SCHEMA" restore_exclude="$RESTORE_EXCLUDE" && backup
}
compare() {     # 7.5
  S "$APP_SCHEMA" "$HERE/compare.sql" check bkp_schema="$BKP_SCHEMA" restore_exclude="$RESTORE_EXCLUDE"
}

# ---- 8 ---------------------------------------------------------------------------------------------------------------
test_users() {  # as ADMIN: creating APEX accounts outside an APEX session needs APEX instance rights (script header)
  S ADMIN "$THIS/db/admin/test-users.sql" check
}
db_tests() {    # every release test; a FAIL line or an ORA- / PLS- error fails the step
  local t
  for t in "$THIS"/features/*/tests/*.sql "$THIS"/tests/*.sql; do
    [ -f "$t" ] || continue
    echo "== ${t#"$ROOT"/}"
    S "$APP_SCHEMA" "$t"
  done > "$LOG_DIR/tests-detail.log" 2>&1
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f ": " $0}' "$LOG_DIR/tests-detail.log" | head -50
  local pass fail err
  pass=$(grep -c '^PASS' "$LOG_DIR/tests-detail.log")
  fail=$(grep -c '^FAIL' "$LOG_DIR/tests-detail.log")
  err=$(grep -cE '^(ORA|PLS)-' "$LOG_DIR/tests-detail.log")
  echo "PASS: $pass  FAIL: $fail  errors: $err" | tee "$LOG_DIR/tests-summary"
  [ "$fail" -eq 0 ] && [ "$err" -eq 0 ]
}

# ---- 9.1 -------------------------------------------------------------------------------------------------------------
export_app() {  # APEXlang export (SQLcl) of the application that passed jobs 6-8
  local out=$1 f
  rm -rf "$out"; mkdir -p "$out"
  f=$(mktemp --suffix .sql)
  printf 'apex export -applicationid %s -exptype APEXLANG -split -skipexportdate -dir %s\n' "$APP_ID" "$out" > "$f"
  S "$APP_SCHEMA" "$f" check; local rc=$?; rm -f "$f"
  [ "$rc" -eq 0 ] && find "$out" -name application.apx | grep -q .
}

# every database job: a new random password for the pipeline user, for this job only (set here, outside a step:
# a step runs in a subshell); 24 characters - upper, lower, digits (ADB password rules), no quote
CI_PW="Ci$(openssl rand -hex 10)Z9"
echo "::add-mask::$CI_PW"
export CI_PW
ci_password() { S ADMIN "$HERE/ci-password.sql" check ci_user="$CI_USER" ci_pw="$CI_PW"; }

step ci-password ci_password
case ${1:?usage: run.sh setup|fresh|upgrade <base-ref>|test|export <dir>} in
  setup)
    step 5.1-start-db start_db
    step 5.2-bootstrap bootstrap
    step 5.3-backup-schema backup_schema N ;;
  fresh)
    step 6.0-backup backup
    step 6.1-remove-app remove_app
    step 6.2-deploy-this deploy "$THIS" install
    step 6.3-online-validation validate_online ;;
  upgrade)
    step 7.1-remove-app remove_app
    step 7.2-build-last build_last "${2:?base ref}"
    step 7.2-deploy-last deploy "$LAST/repos/common" install
    step 7.3-restore-data restore
    step 7.4-upgrade-this deploy "$THIS" upgrade
    step 7.5-nothing-lost compare
    step 7.6-online-validation validate_online
    step 7.7-drop-backup-schema backup_schema Y ;;
  test)
    step 8.1-test-users test_users
    step 8.2-db-tests db_tests ;;
  export)
    step 9.1-export export_app "${2:?export dir}" ;;
  *)
    echo "unknown job: $1" >&2; exit 2 ;;
esac
