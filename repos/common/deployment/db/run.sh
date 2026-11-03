#!/bin/bash
# COMMON pipeline - the database jobs on the validation ADB (environment "Oracle DB Dev"). One call per pipeline job:
#   run.sh setup               3   DB setup: 3.1 start the DB (placeholder), 3.2 bootstrap only when needed,
#                                  3.3 backup schema (dropped if it exists, then created), 3.4 APEX-SERT installed
#                                  only when missing or its pinned commit changed
#   run.sh fresh               4   Deploy fresh app: 4.0 back up the app's data, 4.1 remove app + DB objects,
#                                  4.2 deploy this version, 4.3 online validation, 4.4 dependency check (report)
#   run.sh upgrade <base-ref>  5   Upgrade app: 5.1 remove (= 4.1), 5.2 deploy the last release (= 4.2), 5.3 restore
#                                  the data + snapshot, 5.4 upgrade to this version, 5.5 nothing lost,
#                                  5.6 online validation (= 4.3), 5.7 drop the backup schema
#   run.sh test                6   Testing: 6.1 test users, 6.2 DB tests (any FAIL or error stops the pipeline),
#                                  6.3 browser smoke test (video, screenshots, trace), 6.4 APEX-SERT, 6.5 DBSAT
#                                  (6.6 OWASP ZAP runs as a workflow step)
#   run.sh finalize <dir>      7   7.1 APEXlang export of the tested application into <dir>/app,
#                                  7.3 readable YAML export (<dir>/apex-docs), 7.4 SchemaSpy (<dir>/db-docs)
# This version's application must already be built in repos/common/dist/app (pipeline job 1).
# Env: SQL, WALLET, VAL_DB_SERVICE, ADMIN_PW (pipeline user password per job, 3.2, 6.1), XXCUS_PW (3.2 only), LOG_DIR,
#      BASE (pull request base commit, to see whether bootstrap.sql / the SERT pin changed), REPORT_DIR (reports and
#      recordings, uploaded by the workflow), APP_URL (ORDS base URL, lib/app-url.sh), DBSAT_ZIP_URL / DBSAT_ZIP_SHA256
#      (optional: the user's DBSAT download).
# A failing step stops the job (lib/step.sh); the error-handling job reports it on the pull request.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
# shellcheck source=SCRIPTDIR/../app.env
. "$HERE/../app.env"
# shellcheck source=SCRIPTDIR/../tools.env
. "$HERE/../tools.env"
# shellcheck source=SCRIPTDIR/../lib/step.sh
. "$HERE/../lib/step.sh"
export CI_USER
REPORT_DIR=${REPORT_DIR:-$LOG_DIR/../reports}
mkdir -p "$REPORT_DIR"
TOOLS=${RUNNER_TEMP:-/tmp}/pipeline-tools
mkdir -p "$TOOLS"
THIS=$ROOT/repos/common
LAST=${RUNNER_TEMP:-/tmp}/common-last

S() { bash "$HERE/../lib/sql.sh" "$@"; }

# ---- reuse: the database already holds this version (B) -------------------------------------------------------------
reuse_check() {  # 3.2b: same fingerprint as the last passed upgrade test -> jobs 4-5 are skipped (LOG_DIR/reuse)
  local out fp
  if [ -z "${FINGERPRINT:-}" ]; then echo "no fingerprint - deploy as usual"; echo false > "$LOG_DIR/reuse"; return 0; fi
  out=$(S CI "$HERE/deployed.sql" check mode=get fingerprint=-) || { echo "$out"; return 1; }
  fp=$(echo "$out" | sed -n 's/^DEPLOYED //p')
  if [ "$fp" = "$FINGERPRINT" ]; then
    echo "info: the validation database already holds this version ($FINGERPRINT, passed its fresh install and upgrade test) - jobs 4-5 skipped"
    echo true > "$LOG_DIR/reuse"
  else
    echo "this version ($FINGERPRINT) differs from the deployed one (${fp:--}) - fresh install and upgrade test"
    echo false > "$LOG_DIR/reuse"
  fi
}
record_deployed() {  # 5.8: this version passed its fresh install and upgrade test
  S CI "$HERE/deployed.sql" check mode=set fingerprint="${FINGERPRINT:?FINGERPRINT is not set}"
}

# ---- 3 DB setup ------------------------------------------------------------------------------------------------------
start_db() {   # 3.1 placeholder: the OCI start call comes with job 2 (OCI setup); the validation ADB must be up
  echo "3.1 placeholder - the validation database is expected to be running"
}
bootstrap() {  # 3.2 only when the environment is missing or bootstrap.sql changed in this pull request
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
low_service() { echo "$VAL_DB_SERVICE" | sed -E 's/_(high|medium|tp|tpurgent)$/_low/'; }
sert_install() {   # 3.4 APEX-SERT: only when it is not installed (no SERT_CORE.EVAL_PKG) or its pin changed in this PR
  local f n dir=$TOOLS/apex-sert rc
  f=$(mktemp --suffix .sql)
  echo "select 'SERT_EVAL ' || count(*) from dba_objects where owner = 'SERT_CORE' and object_name = 'EVAL_PKG' and object_type = 'PACKAGE BODY' and status = 'VALID';" > "$f"
  n=$(S ADMIN "$f" check | grep -o 'SERT_EVAL [0-9]*' | cut -d' ' -f2); rm -f "$f"
  if [ "${n:-0}" -gt 0 ] && { [ -z "${BASE:-}" ] || git -C "$ROOT" diff --quiet "$BASE" HEAD -- repos/common/deployment/tools.env; }; then
    echo "APEX-SERT is installed - nothing to do"; return 0
  fi
  rm -rf "$dir"; git init -q "$dir" && git -C "$dir" fetch -q --depth 1 "$SERT_REPO" "$SERT_COMMIT" &&
    git -C "$dir" checkout -q FETCH_HEAD || return 1
  # SERT installs only as its installer schema ACDC (Liquibase precondition "RunningAs ACDC"), created by its own
  # script as ADMIN; ACDC gets a random password for this install and is locked again afterwards (SERT install guide)
  ACDC_PW="Ac$(openssl rand -hex 10)Z9"; echo "::add-mask::$ACDC_PW"; export ACDC_PW
  f=$(mktemp --suffix .sql)
  # the script's own password argument is a throw-away value; the real one is set next (never written to a file)
  printf '@%s/product/sert/pre-install/acdc/create_acdc_schema.sql ACDC "Tmp%sZ9" DATA\n' "$dir" "$(openssl rand -hex 10)" > "$f"
  S ADMIN "$f" check; rc=$?; rm -f "$f"; [ "$rc" -eq 0 ] || return 1
  S ADMIN "$HERE/ci-password.sql" check ci_user=ACDC ci_pw="$ACDC_PW" || return 1
  # Liquibase on the LOW service (the HIGH service runs in parallel: ORA-12838 - SERT install guide)
  (cd "$dir" && VAL_DB_SERVICE=$(low_service) S ACDC install.sql check); rc=$?
  f=$(mktemp --suffix .sql); echo "alter user acdc account lock;" > "$f"; S ADMIN "$f" check; rm -f "$f"
  return "$rc"
}
backup_schema() {  # 3.3 (drop_only=N) and 5.7 (drop_only=Y)
  S CI "$HERE/backup-schema.sql" check bkp_schema="$BKP_SCHEMA" ci_user="$CI_USER" drop_only="$1"
}

# ---- shared by 4 and 5 -----------------------------------------------------------------------------------------------
backup() {     # 4.0 and the 5.3 snapshot: the app's data into the backup schema
  S "$APP_SCHEMA" "$HERE/grant-to.sql" check grantee="$BKP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/backup.sql" check app_schema="$APP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/grant-to.sql" check grantee="$APP_SCHEMA"
}
remove_app() { # 4.1 / 5.1
  S CI "$HERE/remove-app.sql" check app_id="$APP_ID" && S "$APP_SCHEMA" "$HERE/clear-schema.sql" check
}
deploy() {     # 4.2 / 5.2 / 5.4: deploy <project dir> install|upgrade - DB scripts, then APEXlang validate + import
  local dir=$1 mode=$2 f out rc
  S "$APP_SCHEMA" "$dir/db/deploy/$mode/run-all.sql" check || return 1
  f=$(mktemp --suffix .sql)
  # validate and import in the same SQLcl session (APEXlang runtime gate)
  printf 'apex validate -input %s\napex import -input %s\n' "$dir/dist/app" "$dir/dist/app" > "$f"
  out=$(S "$APP_SCHEMA" "$f"); rc=$?; rm -f "$f"; echo "$out"
  [ "$rc" -eq 0 ] && echo "$out" | grep -q "Validation successful" && echo "$out" | grep -q "Import successful"
}
validate_online() {  # 4.3 / 5.6
  local pages
  pages=$(find "$THIS/dist/app/pages" -name '*.apx' | wc -l)
  S "$APP_SCHEMA" "$HERE/validate-online.sql" check app_id="$APP_ID" expected_pages="$pages"
}

dependency_check() {  # 4.4 the deployed schema's dependencies vs the generated map (report, never fails the run)
  S "$APP_SCHEMA" "$HERE/dependencies.sql" check out="$REPORT_DIR/dependencies-live.csv" &&
  python3 "$HERE/compare_dependencies.py" "$THIS/db/deploy/dependencies.json" "$REPORT_DIR/dependencies-live.csv" \
    "$REPORT_DIR/dependency-check.md"
}

# ---- 5 only ----------------------------------------------------------------------------------------------------------
build_last() {  # the last release = the pull request's base commit, built the same way
  rm -rf "$LAST"; git -C "$ROOT" worktree prune
  git -C "$ROOT" worktree add -q "$LAST" "$1" && bash "$LAST/repos/common/build.sh" > /dev/null
}
restore() {     # 5.3: data back into the old release, then the snapshot the upgrade is compared with
  local out
  out=$(S "$APP_SCHEMA" "$HERE/restore.sql" check bkp_schema="$BKP_SCHEMA" restore_exclude="$RESTORE_EXCLUDE") || { echo "$out"; return 1; }
  echo "$out"
  if echo "$out" | grep -q '^INFO '; then   # information about the test data (step log only, no annotation)
    echo "info: $(echo "$out" | grep -c '^INFO ') table(s) / key(s) not fully restored - see the INFO lines above"
  fi
  backup
}
compare() {     # 5.5
  S "$APP_SCHEMA" "$HERE/compare.sql" check bkp_schema="$BKP_SCHEMA" restore_exclude="$RESTORE_EXCLUDE"
}

# ---- 6 ---------------------------------------------------------------------------------------------------------------
test_users() {  # as ADMIN: creating APEX accounts outside an APEX session needs APEX instance rights (script header)
  S ADMIN "$THIS/db/admin/test-users.sql" check
}
db_tests() {    # every release test; a FAIL line or an ORA- / PLS- error fails the step
  # order: tests/setup/*.sql (the test fixtures) first, then the feature tests, then tests/*.sql - each in name order.
  # A file runs as the application schema, or as the schema named in a "-- Schema: <NAME>" line in its first 10 lines
  # (e.g. XXCUS for the tests of an application's side); the pipeline user connects through it as a proxy.
  local t schema
  for t in "$THIS"/tests/setup/*.sql "$THIS"/features/*/tests/*.sql "$THIS"/tests/*.sql; do
    [ -f "$t" ] || continue
    schema=$(sed -n '1,10s/^-- Schema: *\([A-Z][A-Z0-9_]*\).*/\1/p' "$t" | head -1)
    echo "== ${t#"$ROOT"/} (as ${schema:-$APP_SCHEMA})"
    S "${schema:-$APP_SCHEMA}" "$t"
  done > "$LOG_DIR/tests-detail.log" 2>&1
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f ": " $0}' "$LOG_DIR/tests-detail.log" | head -50
  local pass fail err
  pass=$(grep -c '^PASS' "$LOG_DIR/tests-detail.log")
  fail=$(grep -c '^FAIL' "$LOG_DIR/tests-detail.log")
  err=$(grep -cE '^(ORA|PLS)-' "$LOG_DIR/tests-detail.log")
  echo "PASS: $pass  FAIL: $fail  errors: $err" | tee "$LOG_DIR/tests-summary"
  [ "$fail" -eq 0 ] && [ "$err" -eq 0 ]
}

ui_smoke() {    # 6.3 every page as each test user (Playwright: video, screenshots, trace)
  local pw
  pw=$(sed -n "s/.*c_password constant varchar2(30) := '\([^']*\)'.*/\1/p" "$THIS/db/admin/test-users.sql")
  UI_PASSWORD=$pw python3 "$HERE/../ui/smoke_ui.py" --base "${APP_URL:?APP_URL is not set}" --app-id "$APP_ID" \
    --app-path "$APP_PATH" --pages "$THIS/dist/app/pages" --users "$UI_USERS" --skip "$UI_SKIP_PAGES" \
    --out "$REPORT_DIR/ui"
}
sert_eval() {   # 6.4 APEX-SERT evaluation (report; findings are listed, the step fails only when SERT cannot run)
  local out
  out=$(S ADMIN "$HERE/sert-eval.sql" check app_id="$APP_ID" out="$REPORT_DIR/apex-sert-findings.csv") || { echo "$out"; return 1; }
  if echo "$out" | grep -q '^SERT-SKIP'; then   # no rules for this APEX version yet: a notice, not a failure
    echo "info: $(echo "$out" | sed -n 's/^SERT-SKIP //p')" | tee "$REPORT_DIR/apex-sert-summary.txt"
    return 0
  fi
  echo "$out" | grep '^SERT ' | tee "$REPORT_DIR/apex-sert-summary.txt"
}
dbsat() {       # 6.5 Oracle DBSAT (collect + report) - needs the user's DBSAT download (repository variables)
  if [ -z "${DBSAT_ZIP_URL:-}" ] || [ -z "${DBSAT_ZIP_SHA256:-}" ]; then
    echo "info: DBSAT skipped - set the repository variables DBSAT_ZIP_URL and DBSAT_ZIP_SHA256 (issue #209)"
    return 0
  fi
  local ic=$TOOLS/instantclient wdir=$TOOLS/wallet d=$TOOLS/dbsat
  rm -rf "$ic" "$wdir" "$d"; mkdir -p "$ic" "$wdir" "$d"
  bash "$HERE/../lib/fetch.sh" "$IC_BASIC_URL" "$IC_BASIC_SHA256" "$ic/basic.zip" &&
  bash "$HERE/../lib/fetch.sh" "$IC_SQLPLUS_URL" "$IC_SQLPLUS_SHA256" "$ic/sqlplus.zip" &&
  bash "$HERE/../lib/fetch.sh" "$DBSAT_ZIP_URL" "$DBSAT_ZIP_SHA256" "$d/dbsat.zip" || return 1
  (cd "$ic" && unzip -qo basic.zip && unzip -qo sqlplus.zip) && (cd "$d" && unzip -qo dbsat.zip) && unzip -qo "${WALLET:?}" -d "$wdir" || return 1
  sed -i "s#?/network/admin#$wdir#" "$wdir/sqlnet.ora"
  local home; home=$(dirname "$(find "$ic" -name sqlplus -type f | head -1)")
  # DBSAT reads the password from the terminal prompt; it is given on stdin and never echoed
  (cd "$d" && export PATH="$home:$PATH" LD_LIBRARY_PATH="$home" TNS_ADMIN="$wdir" &&
    printf '%s\n' "$ADMIN_PW" | ./dbsat collect -n "ADMIN@$VAL_DB_SERVICE" "$REPORT_DIR/dbsat" &&
    ./dbsat report -n "$REPORT_DIR/dbsat")
}

# ---- 7 ---------------------------------------------------------------------------------------------------------------
readable_export() {   # 7.3 the tested application as readable YAML (documentation)
  local out=$1 f
  rm -rf "$out"; mkdir -p "$out"
  f=$(mktemp --suffix .sql)
  printf 'apex export -applicationid %s -exptype READABLE_YAML -split -skipexportdate -dir %s\n' "$APP_ID" "$out" > "$f"
  S "$APP_SCHEMA" "$f" check; local rc=$?; rm -f "$f"
  [ "$rc" -eq 0 ] && [ -n "$(find "$out" -type f | head -1)" ]
}
schemaspy() {   # 7.4 SchemaSpy HTML documentation of the tested schema (tables, columns, comments, keys, diagrams)
  local out=$1 lib=$TOOLS/schemaspy wdir=$TOOLS/wallet-jdbc
  rm -rf "$lib" "$wdir" "$out"; mkdir -p "$lib" "$wdir" "$out"
  bash "$HERE/../lib/fetch.sh" "$SCHEMASPY_URL" "$SCHEMASPY_SHA256" "$lib/schemaspy.jar" &&
  bash "$HERE/../lib/fetch.sh" "$OJDBC_URL" "$OJDBC_SHA256" "$lib/ojdbc11.jar" &&
  bash "$HERE/../lib/fetch.sh" "$ORAPKI_URL" "$ORAPKI_SHA256" "$lib/oraclepki.jar" && unzip -qo "${WALLET:?}" -d "$wdir" || return 1
  # a SchemaSpy database type for a wallet connection (TNS alias + wallet folder); the proxy user reads XXFUSION
  cat > "$lib/ora-wallet.properties" <<PROPS
extends=ora
description=Oracle (wallet)
connectionSpec=jdbc:oracle:thin:@<db>?TNS_ADMIN=<host>
db=TNS alias of the wallet
host=wallet folder
driver=oracle.jdbc.OracleDriver
PROPS
  java -jar "$lib/schemaspy.jar" -t "$lib/ora-wallet.properties" -dp "$lib/ojdbc11.jar:$lib/oraclepki.jar" \
    -db "$VAL_DB_SERVICE" -host "$wdir" -u "${CI_USER}[$APP_SCHEMA]" -p "$CI_PW" -s "$APP_SCHEMA" -cat % \
    -vizjs -noimplied -o "$out" && [ -f "$out/index.html" ]
}

# ---- 7.1 -------------------------------------------------------------------------------------------------------------
export_app() {  # APEXlang export (SQLcl) of the application that passed jobs 4-6
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
case ${1:?usage: run.sh setup|fresh|upgrade <base-ref>|test|finalize <dir>} in
  setup)
    step 3.1-start-db start_db
    step 3.2-bootstrap bootstrap
    step 3.2b-reuse-check reuse_check
    if [ "$(cat "$LOG_DIR/reuse" 2>/dev/null)" != true ]; then step 3.3-backup-schema backup_schema N; fi
    step 3.4-apex-sert sert_install ;;
  fresh)
    step 4.0-backup backup
    step 4.1-remove-app remove_app
    step 4.2-deploy-this deploy "$THIS" install
    step 4.3-online-validation validate_online
    step 4.4-dependency-check dependency_check
    # C: the DB tests run on the fresh install too, so a test failure stops the run before the upgrade test
    step 4.5-test-users test_users
    step 4.6-db-tests db_tests ;;
  upgrade)
    step 5.1-remove-app remove_app
    step 5.2-build-last build_last "${2:?base ref}"
    step 5.2-deploy-last deploy "$LAST/repos/common" install
    step 5.3-restore-data restore
    step 5.4-upgrade-this deploy "$THIS" upgrade
    step 5.5-nothing-lost compare
    step 5.6-online-validation validate_online
    step 5.7-drop-backup-schema backup_schema Y
    step 5.8-record-version record_deployed ;;
  test)   # A: every test step runs; the job fails at the end with all of their failures together
    export KEEP_GOING=1
    step 6.1-test-users test_users
    step 6.2-db-tests db_tests
    step 6.3-browser-tests ui_smoke
    step 6.4-apex-sert sert_eval
    step 6.5-dbsat dbsat
    finish ;;
  finalize)
    step 7.1-export export_app "${2:?output dir}/app"
    step 7.3-apex-docs readable_export "$2/apex-docs"
    step 7.4-db-docs schemaspy "$2/db-docs" ;;
  *)
    echo "unknown job: $1" >&2; exit 2 ;;
esac
