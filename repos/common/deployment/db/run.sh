#!/bin/bash
# COMMON pipeline - the database jobs on the validation ADB (environment "Oracle DB Dev"). One call per pipeline job:
#   run.sh setup               3   DB setup: 3.1 start the DB (placeholder), 3.2 bootstrap only when needed,
#                                  3.3 backup schema (dropped if it exists, then created), 3.4 APEX-SERT installed
#                                  only when missing or its pinned commit changed
#   run.sh quick               4   Quick check (deploy=patch: only code objects changed): 4.Q1 mark the record,
#                                  4.Q2 run the changed code objects alone, 4.Q3 import the app (when it changed),
#                                  4.Q4 online validation, 4.Q5 record, 4.Q6-4.Q8 the tests of what changed; the
#                                  full deploy (jobs 4-6) follows in the same run - a quick check never merges
#   run.sh fresh               4   Deploy fresh app: 4.1 remove app + DB objects, 4.2 deploy this version, 4.2b load
#                                  this version's test data (db/admin/test-data.json), 4.3 online validation,
#                                  4.4 dependency check (report), 4.5 record the fresh install's structure
#   run.sh upgrade <base-ref>  5   Upgrade app: 5.1 remove (= 4.1), 5.2 deploy the last release, 5.3 load the last
#                                  release's test data (from git), 5.4 snapshot, 5.5 upgrade to this version,
#                                  5.6 nothing lost + keys checked, 5.7 load this version's test data again (insert +
#                                  update: the delta), 5.8 same structure as the fresh install, 5.9 online validation,
#                                  5.10 drop the snapshot, 5.11 record the version
#   No test data is kept in the database between runs: it lives in git and is loaded by each run.
# Jobs 4 (application only, quick check), 5 (deploy=upgrade), 6 and 7 first check that the database still holds what
# job 3 found (version guard): a job re-run after another run changed the database stops instead of testing the wrong
# version.
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

# ---- the version record: what the validation database holds (db/deployed.sql, db/decide.py) -----------------------
# Small statements are generated here; every value put in them is checked first (safe): fingerprints, commit ids and
# repository paths only.
safe() { local v; for v in "$@"; do [[ $v =~ ^[A-Za-z0-9_./:-]*$ ]] || { echo "unsafe value: $v" >&2; return 1; }; done; }
ci_exec() {   # ci_exec <login> <statement line>...
  local login=$1 f rc; shift
  f=$(mktemp --suffix .sql); printf '%s\n' "$@" > "$f"; S "$login" "$f" check; rc=$?; rm -f "$f"; return "$rc"
}
read_record() {   # the record into LOG_DIR/record.txt (DEPLOYED / CODE / PASSED / FAILED lines)
  S CI "$HERE/deployed.sql" check mode=get > "$LOG_DIR/record.txt" || { cat "$LOG_DIR/record.txt"; return 1; }
}
decide() {   # 3.2b: reuse | app | patch | full (LOG_DIR/deploy, patch-files, changed-objects, app-changed)
  read_record && python3 "$HERE/decide.py" "$LOG_DIR/record.txt" "$THIS/db/deploy/code-manifest.txt" "$LOG_DIR"
}
key_of() { basename "$1" | sed -E 's/^[0-9]+-//'; }   # install/0050-package-spec-x.pks -> package-spec-x.pks
mark_dirty() {   # before a deploy changes the database: the record no longer claims a version it may not hold
  local what=$1 f keys=""
  case $what in
    all)  ci_exec CI "merge into xxci_deployed t using (select 'COMMON' app_code from dual) s on (t.app_code = s.app_code)" \
            " when matched then update set fingerprint = '-', db_fingerprint = '-', struct_fingerprint = '-', app_fingerprint = '-', verified = 'DIRTY'" \
            " when not matched then insert (app_code, fingerprint, verified) values ('COMMON', '-', 'DIRTY');" \
            "delete from xxci_deployed_code;" "delete from xxci_passed;" "commit;" ;;
    keep-fresh)   # 5.0a: the fresh install's pass (job 4) stays - a restart from job 5 may skip job 4
          ci_exec CI "update xxci_deployed set fingerprint = '-', db_fingerprint = '-', struct_fingerprint = '-', app_fingerprint = '-', verified = 'DIRTY' where app_code = 'COMMON';" \
            "delete from xxci_deployed_code;" "delete from xxci_passed where check_name <> 'fresh';" "commit;" ;;
    app)  ci_exec CI "update xxci_deployed set fingerprint = '-', app_fingerprint = '-' where app_code = 'COMMON';" \
            "delete from xxci_passed where check_name in ('ui', 'sert');" "commit;" ;;
    code) while read -r f; do [ -n "$f" ] || continue; safe "$f" || return 1; keys="$keys,'$(key_of "$f")'"; done < "$LOG_DIR/patch-files"
          ci_exec CI "update xxci_deployed set fingerprint = '-', db_fingerprint = '-' where app_code = 'COMMON';" \
            "update xxci_deployed_code set code_hash = 'APPLYING' where code_key in ('-'$keys);" \
            "delete from xxci_passed where check_name <> 'fresh';" "commit;" ;;
  esac
}
record_deployed() {  # 4.7 / 5.8 (FULL) and 4.Q5 (PATCH): this version passed its deploy
  local verified=$1 k h f lines=()
  safe "${FINGERPRINT:?FINGERPRINT is not set}" "${DB_FINGERPRINT:?DB_FINGERPRINT is not set}" \
       "${STRUCT_FINGERPRINT:?STRUCT_FINGERPRINT is not set}" "${APP_FINGERPRINT:?APP_FINGERPRINT is not set}" || return 1
  lines+=("merge into xxci_deployed t using (select 'COMMON' app_code from dual) s on (t.app_code = s.app_code)"
          " when matched then update set fingerprint = '$FINGERPRINT', db_fingerprint = '$DB_FINGERPRINT', struct_fingerprint = '$STRUCT_FINGERPRINT',"
          "   app_fingerprint = '$APP_FINGERPRINT', verified = '$verified', deployed_on = systimestamp"
          " when not matched then insert (app_code, fingerprint, db_fingerprint, struct_fingerprint, app_fingerprint, verified)"
          "   values ('COMMON', '$FINGERPRINT', '$DB_FINGERPRINT', '$STRUCT_FINGERPRINT', '$APP_FINGERPRINT', '$verified');"
          "delete from xxci_deployed_code;")
  while read -r k h f; do
    [ -n "$k" ] || continue; safe "$k" "$h" || return 1
    lines+=("insert into xxci_deployed_code (code_key, code_hash) values ('$k', '$h');")
  done < "$THIS/db/deploy/code-manifest.txt"
  lines+=("commit;" "prompt DEPLOYED $FINGERPRINT $verified")
  ci_exec CI "${lines[@]}"
}
record_tests() {   # 6.2b: the head commit tested and the test files that failed (run again next time)
  # 4.Q8 (only=failed): the failed files only - the quick check runs a subset, so it never counts as this commit tested
  local f lines=()
  safe "${HEAD_SHA:-}" || return 1
  [ "${1:-}" = failed ] || lines+=("update xxci_deployed set tested_head = '${HEAD_SHA:--}' where app_code = 'COMMON';")
  lines+=("delete from xxci_failed_tests;")
  while read -r f; do
    [ -n "$f" ] || continue; safe "$f" || return 1
    lines+=("insert into xxci_failed_tests (test_file) values ('$f');")
  done < <(cat "$LOG_DIR/failed-tests" 2>/dev/null)
  lines+=("commit;")
  ci_exec CI "${lines[@]}"
  echo "recorded: ${1:+the failed files only (not as tested), }head ${HEAD_SHA:--}, $(grep -c . "$LOG_DIR/failed-tests" 2>/dev/null || echo 0) failed test file(s)"
}
passed_key() {   # what a passed check is valid for: ui -> version + the pages tested; sert / dbsat -> version
  case $1 in
    ui) echo "$FINGERPRINT:$(printf '%s' "${PAGES:-ALL}" | sha256sum | cut -c1-8)" ;;
    *)  echo "$FINGERPRINT" ;;
  esac
}
passed_before() {   # passed_before <check> <login>: the check passed for this version on an earlier run (reuse only)
  local check=$1 login=$2 owner="" k
  [ "${DEPLOY:-full}" = reuse ] && [ -n "${FINGERPRINT:-}" ] || return 1
  [ "$login" = ADMIN ] && owner="$CI_USER."
  k=$(passed_key "$check"); safe "$k" || return 1
  ci_exec "$login" "set heading off feedback off pagesize 0" \
    "select 'PASSED-BEFORE' from ${owner}xxci_passed where check_name = '$check' and fingerprint = '$k';" 2>/dev/null \
    | grep -q '^PASSED-BEFORE'
}
record_passed() {   # record_passed <check> <login>
  local check=$1 login=$2 owner="" k
  [ "$login" = ADMIN ] && owner="$CI_USER."
  k=$(passed_key "$check"); safe "$k" || return 1
  ci_exec "$login" "merge into ${owner}xxci_passed t using (select '$check' check_name from dual) s on (t.check_name = s.check_name)" \
    " when matched then update set fingerprint = '$k', passed_on = systimestamp" \
    " when not matched then insert (check_name, fingerprint) values ('$check', '$k');" "commit;"
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
drop_old_baseline() {   # 3.3b: the kept baseline schema (run 35) is gone - the test data lives in git (db/admin/test-data.json)
  S CI "$HERE/backup-schema.sql" check bkp_schema=XXFUSION_BASE_BKP ci_user="$CI_USER" drop_only=Y
}
backup_schema() {  # 3.3 (drop_only=N) and 5.10 (drop_only=Y)
  S CI "$HERE/backup-schema.sql" check bkp_schema="$BKP_SCHEMA" ci_user="$CI_USER" drop_only="$1"
}

# ---- shared by 4 and 5 -----------------------------------------------------------------------------------------------
backup() {     # 5.4 the snapshot: the app's data into the backup schema
  S "$APP_SCHEMA" "$HERE/grant-to.sql" check grantee="$BKP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/backup.sql" check app_schema="$APP_SCHEMA" &&
  S "$BKP_SCHEMA" "$HERE/grant-to.sql" check grantee="$APP_SCHEMA"
}
remove_app() { # 4.1 / 5.1
  S CI "$HERE/remove-app.sql" check app_id="$APP_ID" && S "$APP_SCHEMA" "$HERE/clear-schema.sql" check
}
test_user_names() {  # every test user: db/admin/test-users.sql and the users the tests make
  cat "$THIS/db/admin/test-users.sql" "$THIS"/tests/*.sql "$THIS"/tests/setup/*.sql "$THIS"/features/*/tests/*.sql 2>/dev/null \
    | grep -oE "(usr|create_local_user)\('[A-Z][A-Z0-9_]*'" | sed -E "s/.*\('//; s/'//" | sort -u | tr '\n' ' '
}
remove_test_accounts() {  # 4.1 (full fresh install): the test users' APEX accounts, which outlive the cleared schema
  local users
  users=$(test_user_names)
  echo "test users: $users"
  S ADMIN "$HERE/remove-test-accounts.sql" check workspace="$WORKSPACE" users="$users"
}
remove_apex_app() {  # 4.1 (application only): the APEX application; the schema, its objects and data stay
  S CI "$HERE/remove-app.sql" check app_id="$APP_ID"
}
deploy() {     # 4.2 / 5.2 / 5.4: deploy <project dir> install|upgrade|app - DB scripts (not for app), then APEXlang validate + import
  local dir=$1 mode=$2 f out rc
  if [ "$mode" != app ]; then S "$APP_SCHEMA" "$dir/db/deploy/$mode/run-all.sql" check || return 1; fi
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
load_data() {   # 4.2b / 5.7 (this version, strict), 5.3 (the last release's own file, strict): insert + update
  local dir=$1 mode=$2 f rc
  f=$(mktemp --suffix .sql)
  python3 "$HERE/load_data.py" "$dir/db/admin/test-data.json" "$mode" "$f" || { rm -f "$f"; return 1; }
  S "$APP_SCHEMA" "$f" check; rc=$?; rm -f "$f"; return "$rc"
}
load_last_data() {   # 5.3: the last release's test data, from git (the release installed in 5.2)
  if [ -f "$LAST/repos/common/db/admin/test-data.json" ]; then
    load_data "$LAST/repos/common" strict
  else   # the first upgrade after the data file came: this version's file on the old structure
    echo "info: the last release has no test data file yet - this version's file is loaded on the old structure (tables and columns the old release does not have are left out, INFO lines)"
    load_data "$THIS" tolerant
  fi
}
schema_summary() {   # the structure lines (schema-summary.sql) into <file>
  S "$APP_SCHEMA" "$HERE/schema-summary.sql" check | sed -n 's/^SCHEMA //p' > "$1"
  [ -s "$1" ] || { echo "no structure read from $APP_SCHEMA"; return 1; }
}
record_install() {   # 4.2a: the install of this version (no data yet) - a data-only fix reloads the data on it (deploy=data)
  safe "${INSTALL_FINGERPRINT:?INSTALL_FINGERPRINT is not set}" || return 1
  ci_exec CI "merge into xxci_passed t using (select 'install' check_name from dual) s on (t.check_name = s.check_name)" \
    " when matched then update set fingerprint = '$INSTALL_FINGERPRINT', passed_on = systimestamp" \
    " when not matched then insert (check_name, fingerprint) values ('install', '$INSTALL_FINGERPRINT');" "commit;" > /dev/null || return 1
  echo "install recorded for $INSTALL_FINGERPRINT (test data not loaded yet)"
}
forget_install() {   # 4.2c: the test data is in - the install record no longer allows a data-only reload
  ci_exec CI "delete from xxci_passed where check_name = 'install';" "commit;" > /dev/null
}
install_guard() {   # 4.0 (deploy=data): the database still holds the install job 3 found
  local out
  safe "${INSTALL_FINGERPRINT:?INSTALL_FINGERPRINT is not set}" || return 1
  out=$(ci_exec CI "set heading off feedback off pagesize 0" \
    "select 'INSTALL-OF ' || fingerprint from xxci_passed where check_name = 'install';") || { echo "$out"; return 1; }
  # SQLcl pads a line with blanks: the value is read as a word (like guard), not as the whole line
  [ "$(echo "$out" | sed -n 's/^INSTALL-OF *//p' | awk 'NR == 1 {print $1}')" = "$INSTALL_FINGERPRINT" ] \
    || { echo "$out" | grep -v '^ *$' | head -5; echo "FAIL the database no longer holds the install of this version ($INSTALL_FINGERPRINT) - start the run again (job 3 decides a full deploy)"; return 1; }
  echo "the database holds the install of this version ($INSTALL_FINGERPRINT) - test data only"
}
record_fresh() {   # 4.5: the fresh install's structure (compared with the upgraded database in 5.8) and its pass
  local f n=0 line q="'" lines=("delete from xxci_fresh_schema;")
  safe "${FINGERPRINT:?FINGERPRINT is not set}" || return 1
  f=$LOG_DIR/fresh-schema.txt
  schema_summary "$f" || return 1
  while IFS= read -r line; do
    n=$((n + 1)); lines+=("insert into xxci_fresh_schema (line_no, line) values ($n, '${line//$q/$q$q}');")
  done < "$f"
  lines+=("merge into xxci_passed t using (select 'fresh' check_name from dual) s on (t.check_name = s.check_name)"
          " when matched then update set fingerprint = '$FINGERPRINT', passed_on = systimestamp"
          " when not matched then insert (check_name, fingerprint) values ('fresh', '$FINGERPRINT');" "commit;")
  ci_exec CI "${lines[@]}" > /dev/null || return 1
  echo "fresh install recorded for $FINGERPRINT: $(grep -vc '^R ' "$f") structure line(s), $(grep -c '^R ' "$f") table row count(s)"
}
same_as_fresh() {   # 5.8: the upgraded database has the structure of the fresh install of this version
  local up=$LOG_DIR/upgraded-schema.txt fresh=$LOG_DIR/fresh-schema.txt out only_up only_fresh
  safe "${FINGERPRINT:?FINGERPRINT is not set}" || return 1
  out=$(ci_exec CI "set heading off feedback off pagesize 0 linesize 4000 trimspool on" \
    "select 'FRESH-OF ' || fingerprint from xxci_passed where check_name = 'fresh';" \
    "select 'FRESH ' || line from xxci_fresh_schema order by line_no;") || { echo "$out"; return 1; }
  if [ "$(echo "$out" | sed -n 's/^FRESH-OF *//p' | awk 'NR == 1 {print $1}')" != "$FINGERPRINT" ]; then
    echo "FAIL no fresh install of this version ($FINGERPRINT) is recorded - job 4 must pass first"; return 1
  fi
  echo "$out" | sed -n 's/^FRESH //p' > "$fresh"
  schema_summary "$up" || return 1
  only_up=$(grep -v '^R ' "$up" | sort | comm -23 - <(grep -v '^R ' "$fresh" | sort))
  only_fresh=$(grep -v '^R ' "$fresh" | sort | comm -23 - <(grep -v '^R ' "$up" | sort))
  # row counts: for information (the upgraded database holds the last release's data and this version's)
  join <(grep '^R ' "$fresh" | cut -c3- | sort) <(grep '^R ' "$up" | cut -c3- | sort) \
    | awk '$2 != $3 {print "info: rows in " $1 ": fresh install " $2 ", upgraded " $3}' | head -50
  if [ -n "$only_up$only_fresh" ]; then
    [ -z "$only_up" ] || echo "$only_up" | head -100 | sed 's/^/FAIL only after the upgrade: /'
    [ -z "$only_fresh" ] || echo "$only_fresh" | head -100 | sed 's/^/FAIL only in the fresh install: /'
    echo "the upgraded database differs from the fresh install of this version: $(echo "$only_up" | grep -c .) line(s) only after the upgrade, $(echo "$only_fresh" | grep -c .) only in the fresh install"
    return 1
  fi
  echo "the upgraded database has the fresh install's structure: $(grep -vc '^R ' "$up") line(s) compared"
}
guard() {   # guard version|app|patch|upgrade <login>: the database still holds what job 3 found
  local what=$1 login=$2 owner="" out dep fp db struct verified fresh ok=1
  [ "$login" = ADMIN ] && owner="$CI_USER."
  out=$(ci_exec "$login" "set heading off feedback off pagesize 0" \
    "select 'GUARD ' || fingerprint || ' ' || nvl(db_fingerprint, '-') || ' ' || nvl(struct_fingerprint, '-') || ' ' || nvl(verified, 'FULL') from ${owner}xxci_deployed where app_code = 'COMMON';" \
    "select 'GUARD-FRESH ' || fingerprint from ${owner}xxci_passed where check_name = 'fresh';") || { echo "$out"; return 1; }
  dep=$(echo "$out" | grep -m1 '^GUARD ' || true)
  read -r _ fp db struct verified <<< "${dep:-GUARD - - - DIRTY}"
  fresh=$(echo "$out" | sed -n 's/^GUARD-FRESH //p' | head -1)
  case $what in
    version) [ "$fp" = "${FINGERPRINT:-}" ] && [ "$verified" = FULL ] || ok=0 ;;
    app)     [ "$db" = "${DB_FINGERPRINT:-}" ] && [ "$verified" = FULL ] || ok=0 ;;
    patch)   [ "$struct" = "${STRUCT_FINGERPRINT:-}" ] && [ "$verified" != DIRTY ] || ok=0 ;;
    upgrade) [ "$fresh" = "${FINGERPRINT:-}" ] || ok=0 ;;
  esac
  if [ "$ok" = 1 ]; then echo "the database holds what job 3 found ($what: ${fp:0:16} $verified)"; return 0; fi
  echo "FAIL the database no longer holds what job 3 found for this run ($what check: version ${fp:0:16}, $verified, fresh install of ${fresh:--}) - another run changed it in between: re-run all jobs (from job 1)"
  return 1
}
compare() {     # 5.6
  S "$APP_SCHEMA" "$HERE/compare.sql" check bkp_schema="$BKP_SCHEMA" restore_exclude="$RESTORE_EXCLUDE"
}

# ---- 6 ---------------------------------------------------------------------------------------------------------------
test_users() {  # as ADMIN: creating APEX accounts outside an APEX session needs APEX instance rights (script header)
  S ADMIN "$THIS/db/admin/test-users.sql" check
}
db_tests() {    # the DB tests; a FAIL line or an ORA- / PLS- error fails the step
  # order: tests/setup/*.sql (the test fixtures) first, then the feature tests, then tests/*.sql - each in name order.
  # DB_TESTS (job 1, checks/affected.py): ALL, or the tests a pull request affects (the fixtures always run).
  # A file runs as the application schema, or as the schema named in a "-- Schema: <NAME>" line in its first 10 lines.
  # I: consecutive files of one schema run in ONE SQLcl session (one start-up and sign-in, not one per file); between
  # files the session is reset (rollback, no APEX session, package state cleared). A file that ends the session itself
  # (exit / quit) runs in its own session.
  local t schema rel wrapper="" group="" n=0
  : > "$LOG_DIR/tests-expected"
  flush() {   # the open session's files; the next file starts a new session (also after a file run on its own)
    if [ -n "$wrapper" ]; then S "$group" "$wrapper"; rm -f "$wrapper"; fi
    wrapper=""; group=""
  }
  for t in "$THIS"/tests/setup/*.sql "$THIS"/features/*/tests/*.sql "$THIS"/tests/*.sql; do
    [ -f "$t" ] || continue
    rel=${t#"$ROOT"/}
    case $rel in
      repos/common/tests/setup/*) ;;
      *) if [ "${DB_TESTS:-ALL}" != ALL ] && ! printf ' %s ' "$DB_TESTS" | grep -qF " $rel "; then continue; fi ;;
    esac
    n=$((n + 1)); echo "$rel" >> "$LOG_DIR/tests-expected"
    schema=$(sed -n '1,10s/^-- Schema: *\([A-Z][A-Z0-9_]*\).*/\1/p' "$t" | head -1); schema=${schema:-$APP_SCHEMA}
    # a file that ends the session (exit / quit) or runs other scripts (@ / @@ - their settings would carry over)
    # runs in its own session
    if grep -qiE '^[[:space:]]*(exit|quit\b|@)' "$t"; then
      flush; echo "== $rel (as $schema)"; S "$schema" "$t"; continue
    fi
    if [ -z "$wrapper" ] || [ "$schema" != "$group" ]; then flush; group=$schema; wrapper=$(mktemp --suffix .sql); fi
    cat >> "$wrapper" <<SQL
prompt == $rel (as $schema)
@"$t"
rollback;
begin apex_session.delete_session; exception when others then null; end;
/
exec dbms_session.reset_package
set define on serveroutput on size unlimited
SQL
  done > "$LOG_DIR/tests-detail.log" 2>&1
  flush >> "$LOG_DIR/tests-detail.log" 2>&1
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f ": " $0}' "$LOG_DIR/tests-detail.log" | head -200   # L4
  # the test files that failed, and those that never ran (a session ended early): run again by the next run (Q2)
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f}' "$LOG_DIR/tests-detail.log" | sort -u > "$LOG_DIR/failed-tests"
  grep -oE '^== [^ ]+' "$LOG_DIR/tests-detail.log" | cut -c4- | sort -u > "$LOG_DIR/tests-ran"
  local missing
  missing=$(sort -u "$LOG_DIR/tests-expected" | comm -23 - "$LOG_DIR/tests-ran")
  if [ -n "$missing" ]; then printf '%s\n' "$missing" >> "$LOG_DIR/failed-tests"; sort -u -o "$LOG_DIR/failed-tests" "$LOG_DIR/failed-tests"; fi
  local pass fail err
  pass=$(grep -c '^PASS' "$LOG_DIR/tests-detail.log")
  fail=$(grep -c '^FAIL' "$LOG_DIR/tests-detail.log")
  err=$(grep -cE '^(ORA|PLS)-' "$LOG_DIR/tests-detail.log")
  if [ "${DB_TESTS:-ALL}" = ALL ]; then echo "$n test file(s): all"; else echo "$n test file(s): the fixtures and the tests this pull request affects"; fi
  echo "PASS: $pass  FAIL: $fail  errors: $err" | tee "$LOG_DIR/tests-summary"
  # every file that should run must have run: a file that ends its session early would otherwise pass unseen
  if [ -n "$missing" ]; then
    echo "FAIL test files expected: $n, ran: $(grep -c . "$LOG_DIR/tests-ran") - did not run: $(echo "$missing" | tr '\n' ' ')"
    return 1
  fi
  [ "$fail" -eq 0 ] && [ "$err" -eq 0 ]
}

select_tests() {   # 6.0 / 4.Q6: which DB tests run (LOG_DIR/db-tests; the fixtures always run)
  # full (a fresh install and upgrade test ran): the tests of the pull request (DB_TESTS, job 1 - ALL in the full run).
  # delta (reuse / app: the database held a fully verified version): only what changed since the head commit last
  #   tested, and the test files that failed then (Q2) - everything else passed against the same code.
  # quick (job 4 quick check): the tests of the changed code objects and of every object that calls them (the live
  #   database's dependencies), the delta, and the files that failed last time - never ALL (the full deploy follows).
  local kind=$1 prev delta="" sel="" names
  if [ "$kind" = full ]; then
    echo "${DB_TESTS:-ALL}" > "$LOG_DIR/db-tests"; echo "the tests of this pull request: ${DB_TESTS:-ALL}"; return 0
  fi
  read_record || return 1
  prev=$(awk '$1 == "DEPLOYED" {print $7}' "$LOG_DIR/record.txt")
  if [ -n "$prev" ] && [ "$prev" != - ] && git -C "$ROOT" cat-file -e "$prev^{commit}" 2>/dev/null; then
    delta=$(cd "$ROOT" && python3 "$HERE/../checks/affected.py" "$prev" | sed -n 's/^db_tests=//p')
    echo "changed since the last tested commit ${prev:0:7}: $delta"
  else
    delta=ALL; echo "no tested commit recorded (or not in this checkout) - the tests of this pull request"
  fi
  if [ "$kind" = quick ]; then
    names=$(tr '\n' ' ' < "$LOG_DIR/changed-objects")
    if [ -n "${names// /}" ]; then
      callers "$names" > "$LOG_DIR/callers" || return 1
      echo "changed code objects: $names; their callers: $(tr '\n' ' ' < "$LOG_DIR/callers")"
      sel=$(cd "$ROOT" && python3 "$HERE/../checks/affected.py" --objects "$names $(tr '\n' ' ' < "$LOG_DIR/callers")" | sed -n 's/^db_tests=//p')
    fi
    [ "$delta" = ALL ] && delta=""   # the full deploy runs everything after the quick check
  elif [ "$delta" = ALL ]; then
    echo "${DB_TESTS:-ALL}" > "$LOG_DIR/db-tests"; echo "the tests of this pull request: ${DB_TESTS:-ALL}"; return 0
  fi
  sel=$({ tr ' ' '\n' <<< "$sel $delta"; awk '$1 == "FAILED" {print $2}' "$LOG_DIR/record.txt"; } | grep -vE '^(NONE)?$' \
        | while read -r f; do [ -f "$ROOT/$f" ] && echo "$f"; done | sort -u | tr '\n' ' ')
  echo "${sel:-NONE}" > "$LOG_DIR/db-tests"
  echo "DB tests this run (with the fixtures): ${sel:-none besides the fixtures}"
}
callers() {   # the objects that use the given ones (all levels), from the live database
  local n list=""
  for n in $1; do safe "$n" || return 1; list="$list,'$n'"; done
  ci_exec "$APP_SCHEMA" "set heading off feedback off pagesize 0" \
    "select distinct 'DEP ' || name from user_dependencies start with referenced_owner = user and referenced_name in ('-'$list)" \
    " connect by nocycle prior name = referenced_name and referenced_owner = user;" | sed -n 's/^DEP //p' | sort -u
}
apply_code() {   # 4.Q2 the changed code objects alone, in install order, in one session (each file: one CREATE OR REPLACE)
  local f w n=0
  w=$(mktemp --suffix .sql); echo "set define off" > "$w"
  while read -r f; do
    [ -n "$f" ] || continue; safe "$f" || return 1
    printf 'prompt == %s\n@"%s"\n' "$f" "$THIS/db/deploy/$f" >> "$w"; n=$((n + 1))
  done < "$LOG_DIR/patch-files"
  if [ "$n" -eq 0 ]; then rm -f "$w"; echo "no code object changed since the deployed version"; return 0; fi
  S "$APP_SCHEMA" "$w" check; local rc=$?; rm -f "$w"
  [ "$rc" -eq 0 ] && echo "$n code object file(s) applied"
}

test_passwords() {  # 6.1b (H1): this run's random password for every test user
  S ADMIN "$HERE/test-passwords.sql" check workspace="$WORKSPACE" users="$(test_user_names)" pw="$UI_PW"
}
ui_smoke() {    # 6.3 every page (on a pull request: its pages, PAGES from job 1) as each test user (Playwright: video, screenshots, trace)
  UI_PASSWORD=$UI_PW python3 "$HERE/../ui/smoke_ui.py" --base "${APP_URL:?APP_URL is not set}" --app-id "$APP_ID" \
    --app-path "$APP_PATH" --pages "$THIS/dist/app/pages" --users "$UI_USERS" --skip "$UI_SKIP_PAGES" \
    --only "$( [ "${PAGES:-ALL}" = ALL ] || echo "$PAGES")" --out "$REPORT_DIR/ui"   # PAGES: a PR's pages (K)
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
if [ "${1:-}" != ui ]; then   # the browser job never signs in as the pipeline user
  CI_PW="Ci$(openssl rand -hex 10)Z9"
  echo "::add-mask::$CI_PW"
  export CI_PW
fi
ci_password() { S ADMIN "$HERE/ci-password.sql" check ci_user="$CI_USER" ci_pw="$CI_PW"; }

# the browser job (ui) runs beside the DB-test job and never signs in as the pipeline user: it leaves the password
# alone (a new one would lock the other job out)
if [ "${1:-}" != ui ]; then step ci-password ci_password; fi
if [ "${1:-}" = ui ]; then   # H1: the test users' password of this run (random, masked, never in git or a file)
  UI_PW="Ui$(openssl rand -hex 10)Z9"
  echo "::add-mask::$UI_PW"
  export UI_PW
fi
case ${1:?usage: run.sh setup|quick|fresh|upgrade <base-ref>|test|ui|finalize <dir>|docs <dir>} in
  setup)
    step 3.1-start-db start_db
    step 3.2-bootstrap bootstrap
    step 3.2b-deploy-decision decide
    # the snapshot schema serves the upgrade test only (a quick check is followed by the full deploy)
    if grep -qE '^(full|patch|upgrade|data)$' "$LOG_DIR/deploy"; then
      step 3.3-backup-schema backup_schema N
    fi
    step 3.3b-drop-old-baseline drop_old_baseline
    step 3.4-apex-sert sert_install ;;
  quick)   # job 4 quick check (deploy=patch): the changed code alone, then its tests; the full deploy follows
    tr ' ' '\n' <<< "${PATCH_FILES:-}" | grep . > "$LOG_DIR/patch-files"
    tr ' ' '\n' <<< "${CHANGED_OBJECTS:-}" | grep . > "$LOG_DIR/changed-objects"
    step 4.Q0-version-guard guard patch CI
    step 4.Q1-mark-record mark_dirty code
    step 4.Q2-apply-code apply_code
    if [ "${APP_CHANGED:-true}" = true ]; then
      step 4.Q3-import-app deploy "$THIS" app
    else
      step 4.Q3-import-app echo "info: the application (without its supporting objects) is the deployed one - not imported for the quick check"
    fi
    step 4.Q4-online-validation validate_online
    step 4.Q5-record-version record_deployed PATCH
    step 4.Q6-select-tests select_tests quick
    DB_TESTS=$(cat "$LOG_DIR/db-tests"); export DB_TESTS
    export KEEP_GOING=1
    step 4.Q7-db-tests db_tests
    step 4.Q8-record-tests record_tests failed
    finish ;;
  fresh)
    if [ "${APP_ONLY:-false}" = true ]; then
      # the database already holds this version's database objects: only the APEX application is replaced
      step 4.0-version-guard guard app CI
      step 4.1a-mark-record mark_dirty app
      step 4.1-remove-apex-app remove_apex_app
      step 4.2-import-app deploy "$THIS" app
    else
      if [ "${DEPLOY:-full}" = data ]; then
        step 4.0-install-guard install_guard
      else
        step 4.1a-mark-record mark_dirty all
        step 4.1-remove-app remove_app
        step 4.1b-remove-test-accounts remove_test_accounts
        step 4.2-deploy-this deploy "$THIS" install
        step 4.2a-record-install record_install
      fi
      step 4.2b-load-test-data load_data "$THIS" strict
      step 4.2c-data-loaded forget_install
    fi
    step 4.3-online-validation validate_online
    step 4.4-dependency-check dependency_check
    if [ "${APP_ONLY:-false}" != true ]; then step 4.5-record-fresh-install record_fresh; fi
    # (C - the DB tests on the fresh install - is held back: the tests still need the data an upgraded database has)
    # F: no upgrade test when this version has the base's database scripts - the fresh install is the deployed version
    # application only: no upgrade test (job 5) - this version is deployed now
    if [ "${APP_ONLY:-false}" = true ]; then step 4.7-record-version record_deployed FULL; fi ;;
  upgrade)
    # deploy=upgrade (job 4 skipped: it passed for this version on an earlier run) - that pass must still be recorded
    if [ "${DEPLOY:-full}" = upgrade ]; then step 5.0-version-guard guard upgrade CI; fi
    step 5.0a-mark-record mark_dirty keep-fresh
    step 5.1-remove-app remove_app
    step 5.2-build-last build_last "${2:?base ref}"
    step 5.2-deploy-last deploy "$LAST/repos/common" install
    step 5.3-load-last-test-data load_last_data
    step 5.4-snapshot backup
    step 5.5-upgrade-this deploy "$THIS" upgrade
    step 5.6-nothing-lost compare
    step 5.7-load-this-test-data load_data "$THIS" strict
    step 5.8-same-as-fresh-install same_as_fresh
    step 5.9-online-validation validate_online
    step 5.10-drop-snapshot backup_schema Y
    step 5.11-record-version record_deployed FULL ;;
  test)   # job 6 (database): A - every step runs; the job fails at the end with all of their failures together
    export KEEP_GOING=1
    # reuse / app: the database held a fully verified version - only what changed since the last tested commit (Q2)
    case ${DEPLOY:-full} in reuse|app) kind="delta" ;; *) kind="full" ;; esac
    step 6.0a-version-guard guard version CI || finish
    step 6.0-select-tests select_tests "$kind"
    DB_TESTS=$(cat "$LOG_DIR/db-tests" 2>/dev/null || echo "${DB_TESTS:-ALL}"); export DB_TESTS
    step 6.2-db-tests db_tests
    step 6.2b-record-tests record_tests
    # reuse: the application and database are the ones scanned - a scan that passed for this version is not run again (Q3)
    for c in sert:6.4-apex-sert:sert_eval dbsat:6.5-dbsat:dbsat; do
      IFS=: read -r check name fn <<< "$c"
      if passed_before "$check" CI; then
        step "$name" echo "info: $check passed for this version on an earlier run (database not redeployed) - not run again"
      elif step "$name" "$fn"; then
        record_passed "$check" CI > /dev/null || true
      fi
    done
    finish ;;
  ui)     # job 6 (browser, in parallel - G): test users, then every page as each of them
    export KEEP_GOING=1
    # reuse: the application is the one tested - a browser test that passed for this version and these pages is not
    # run again (Q4)
    step 6.0b-version-guard guard version ADMIN || finish
    if passed_before ui ADMIN; then
      step 6.3-browser-tests echo "info: the browser test passed for this version on an earlier run (application not redeployed) - not run again"
      finish; exit 0
    fi
    step 6.1-test-users test_users
    step 6.1b-test-passwords test_passwords
    step 6.3-browser-tests ui_smoke
    if [ ! -s "$LOG_DIR/failed" ]; then record_passed ui ADMIN > /dev/null || true; fi
    finish ;;
  finalize)
    step 7.0-version-guard guard version CI
    step 7.1-export export_app "${2:?output dir}/app" ;;
  docs)   # E: after the merge (7.3-7.4 are not needed to merge)
    step 7.3-apex-docs readable_export "${2:?output dir}/apex-docs"
    step 7.4-db-docs schemaspy "$2/db-docs" ;;
  *)
    echo "unknown job: $1" >&2; exit 2 ;;
esac
