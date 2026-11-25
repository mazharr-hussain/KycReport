#!/bin/bash
# KYC deploy check (I-096, #272) - job K of the pipeline, for a "KYC Release <N>: ..." pull request. KYC (app 134,
# schema XXCUS) is deployed on top of the COMMON the validation database already holds (the last COMMON release);
# COMMON itself is not touched. Every step runs (KEEP_GOING) and the job fails at the end with all of the failures,
# so one run lists everything that does not work yet.
#   K.0 the pipeline user's password for this job
#   K.1 import app 134 (APEXlang validate + import; its database objects follow in K.3)
#   K.2 register KYC in COMMON (XXFND_ONBOARD_PKG.ONBOARD_SELF, as XXCUS): the grants on the COMMON objects to XXCUS,
#       which the KYC tables and packages need
#   K.3 the KYC database install (repos/kyc/db/deploy/install/run-all.sql, as XXCUS)
#   K.4 import app 134 again, now on its database objects
#   K.5 online validation (no invalid object, app 134 installed with every page)
#   K.6 the KYC DB tests (repos/kyc/tests/*.sql, as XXCUS; a FAIL line or an ORA- / PLS- error fails the step)
# The KYC application must already be built in repos/kyc/dist/app and repos/kyc/db/deploy (the workflow builds it).
# Env: as db/run.sh (SQL, WALLET, VAL_DB_SERVICE, ADMIN_PW, LOG_DIR, REPORT_DIR).
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../../.." && pwd)
THIS=$ROOT/repos/kyc
# shellcheck source=SCRIPTDIR/../../../kyc/deployment/app.env
. "$THIS/deployment/app.env"
# shellcheck source=SCRIPTDIR/../lib/step.sh
. "$HERE/../lib/step.sh"
export CI_USER
REPORT_DIR=${REPORT_DIR:-$LOG_DIR/../reports}
mkdir -p "$REPORT_DIR"

S() { bash "$HERE/../lib/sql.sh" "$@"; }

ci_password() { S ADMIN "$HERE/ci-password.sql" check ci_user="$CI_USER" ci_pw="$CI_PW"; }
import_app() {   # K.1 / K.4: validate and import in the same SQLcl session (APEXlang runtime gate)
  local f out rc
  f=$(mktemp --suffix .sql)
  printf 'apex validate -input %s\napex import -input %s\n' "$THIS/dist/app" "$THIS/dist/app" > "$f"
  out=$(S "$APP_SCHEMA" "$f"); rc=$?; rm -f "$f"; echo "$out"
  [ "$rc" -eq 0 ] && echo "$out" | grep -q "Validation successful" && echo "$out" | grep -q "Import successful"
}
onboard() {   # K.2: the application registers itself in COMMON (the routine COMMON grants every workspace schema)
  local f rc
  f=$(mktemp --suffix .sql)
  cat > "$f" <<SQL
begin
    xxfusion.xxfnd_onboard_pkg.onboard_self(p_schema => user, p_application_code => '$APP_CODE');
    commit;
    dbms_output.put_line('onboarded: ' || xxfusion.xxfnd_onboard_pkg.is_onboarded('$APP_CODE'));
end;
/
SQL
  S "$APP_SCHEMA" "$f" check; rc=$?; rm -f "$f"; return "$rc"
}
install() {   # K.3
  S "$APP_SCHEMA" "$THIS/db/deploy/install/run-all.sql" check
}
validate_online() {   # K.5
  local pages
  pages=$(find "$THIS/dist/app/pages" -name '*.apx' | wc -l)
  S "$APP_SCHEMA" "$HERE/validate-online.sql" check app_id="$APP_ID" expected_pages="$pages"
}
db_tests() {   # K.6: each file in its own session; a FAIL line or an ORA- / PLS- error fails the step
  local t n=0
  : > "$LOG_DIR/kyc-tests-detail.log"
  for t in "$THIS"/tests/*.sql; do
    [ -f "$t" ] || continue
    n=$((n + 1))
    { echo "== ${t#"$ROOT"/}"; S "$APP_SCHEMA" "$t"; } >> "$LOG_DIR/kyc-tests-detail.log" 2>&1
  done
  awk '/^== /{f=$2} /^(FAIL|ORA-|PLS-)/{print f ": " $0}' "$LOG_DIR/kyc-tests-detail.log" | head -200
  local pass fail err
  pass=$(grep -c '^PASS' "$LOG_DIR/kyc-tests-detail.log")
  fail=$(grep -c '^FAIL' "$LOG_DIR/kyc-tests-detail.log")
  err=$(grep -cE '^(ORA|PLS)-' "$LOG_DIR/kyc-tests-detail.log")
  echo "$n KYC test file(s)"
  echo "PASS: $pass  FAIL: $fail  errors: $err"
  [ "$fail" -eq 0 ] && [ "$err" -eq 0 ]
}

# a new random password for the pipeline user, for this job only (outside a step: a step runs in a subshell)
CI_PW="Ci$(openssl rand -hex 10)Z9"
echo "::add-mask::$CI_PW"
export CI_PW
step K.0-ci-password ci_password
export KEEP_GOING=1
step K.1-import-app import_app
step K.2-register-in-common onboard
step K.3-install-db install
step K.4-import-app-again import_app
step K.5-online-validation validate_online
step K.6-db-tests db_tests
finish
