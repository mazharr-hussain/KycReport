#!/bin/bash
# COMMON stage 2 - database (validation ADB, environment "Oracle DB Dev"); runs only after stage 1 passed.
# Usage: run.sh <base-ref>   (the last released version, e.g. the PR's base commit or origin/main)
#   bootstrap      users, grants, workspace XXCUS (creates only what is missing)
#   uninstall      app 135 removed, every XXFUSION object dropped
#   deploy-this    this version: DB objects (install) + app import
#   uninstall      again
#   deploy-last    the last released version: DB objects (install) + app import
#   upgrade-this   this version on top: upgrade scripts + app import
#   rerun-this     this version again: install scripts + app import (nothing may fail)
#   invalid        no invalid object in XXFUSION
#   test-users, tests (FAIL lines are reported, not fatal)
# Env: SQL, WALLET, VAL_DB_SERVICE, ADMIN_PW, XXCUS_PW (App Builder user XXCUS). A failing step stops the run.
set -uo pipefail
BASE_REF=${1:?base ref}
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/../../../.." && pwd)
. "$HERE/../lib/step.sh"
S() { sh "$HERE/../lib/sql.sh" "$@"; }
THIS=$ROOT/repos/common
LAST=${RUNNER_TEMP:-/tmp}/common-last

bootstrap() {
  f=$(mktemp)
  { echo "set define on verify off"; printf 'define xxcus_pw = "%s"\n' "$XXCUS_PW"; echo "@$HERE/bootstrap.sql"; } > "$f"
  S ADMIN "$f" check; rc=$?; rm -f "$f"; return $rc
}
uninstall() {
  f=$(mktemp --suffix .sql)
  cat > "$f" <<'SQL'
declare
    l_n pls_integer;
begin
    select count(*) into l_n from apex_applications where application_id = 135;
    if l_n > 0 then
        apex_instance_admin.remove_application(p_application_id => 135);
        commit;
        dbms_output.put_line('removed application 135');
    end if;
end;
/
SQL
  S ADMIN "$f" check && S XXFUSION "$HERE/clear-schema.sql" check; rc=$?; rm -f "$f"; return $rc
}
db() { S XXFUSION "$1/db/deploy/$2/run-all.sql" check; }   # db <project dir> install|upgrade
app() {                                                    # app <project dir>: validate + import app 135
  f=$(mktemp --suffix .sql)
  printf 'apex validate -input %s\napex import -input %s\n' "$1/dist/app" "$1/dist/app" > "$f"
  out=$(S XXFUSION "$f"); rc=$?; rm -f "$f"; echo "$out"
  [ $rc -eq 0 ] && echo "$out" | grep -q "Validation successful" && echo "$out" | grep -q "Import successful"
}
last_version() {
  rm -rf "$LAST"; git -C "$ROOT" worktree prune
  git -C "$ROOT" worktree add -q "$LAST" "$BASE_REF" && sh "$LAST/repos/common/build.sh" > /dev/null
}
invalid() {
  f=$(mktemp --suffix .sql)
  cat > "$f" <<'SQL'
exec dbms_utility.compile_schema(schema => user, compile_all => false)
select 'INVALID ' || object_type || ' ' || object_name from user_objects where status = 'INVALID';
SQL
  out=$(S XXFUSION "$f" check); rc=$?; rm -f "$f"; echo "$out"
  [ $rc -eq 0 ] && ! echo "$out" | grep -q '^INVALID '
}
tests() {
  for t in "$THIS"/features/*/tests/*.sql "$THIS"/tests/*.sql; do
    [ -f "$t" ] && { echo "== ${t#$ROOT/}"; S XXFUSION "$t"; }
  done > "$LOG_DIR/tests-detail.log" 2>&1
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f ": " $0}' "$LOG_DIR/tests-detail.log" | head -50
  echo "PASS: $(grep -c '^PASS' "$LOG_DIR/tests-detail.log")  FAIL: $(grep -c '^FAIL' "$LOG_DIR/tests-detail.log")  errors: $(grep -cE '^(ORA|PLS)-' "$LOG_DIR/tests-detail.log")" | tee "$LOG_DIR/tests-summary"
}

step bootstrap bootstrap
step uninstall-1 uninstall
step deploy-this-db db "$THIS" install
step deploy-this-app app "$THIS"
step uninstall-2 uninstall
step build-last-version last_version
step deploy-last-db db "$LAST/repos/common" install
step deploy-last-app app "$LAST/repos/common"
step upgrade-this-db db "$THIS" upgrade
step upgrade-this-app app "$THIS"
step rerun-this-db db "$THIS" install
step rerun-this-app app "$THIS"
step invalid-objects invalid
step test-users S XXFUSION "$THIS/db/admin/test-users.sql" check
step tests tests
