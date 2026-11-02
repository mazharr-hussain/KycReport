#!/bin/bash
# Runs one SQL file on the validation database with SQLcl: sql.sh <login> <sql-file> [check] [name=value ...]
#   <login>  ADMIN       - ADMIN with VAL_DB_ADMIN_PASSWORD (bootstrap and test users only)
#            CI          - the pipeline user CI_USER with its password for this job (CI_PW, set by db/run.sh)
#            ACDC        - APEX-SERT's installer schema (ACDC_PW, set by db/run.sh for the install only)
#            <SCHEMA>    - proxy CI_USER[<SCHEMA>] (schema passwords are random and unknown)
#   check    stop at the first SQL error; fail on SP2- errors or code compiled with errors (install steps).
#            Without it everything runs (tests).
#   name=value  SQLcl substitution variables for the script (DEFINE name = "value").
# The connect line goes to SQLcl on stdin (never on the command line or in a file), as the Oracle SQLcl CI/CD
# guidance asks. Env: SQL (SQLcl binary), WALLET, VAL_DB_SERVICE, ADMIN_PW, CI_PW, CI_USER.
set -uo pipefail
login=$1; file=$2; shift 2
mode=
if [ "${1:-}" = check ]; then mode=check; shift; fi
case $login in
  ADMIN) who=ADMIN; pw=${ADMIN_PW:?ADMIN_PW is not set} ;;
  CI)    who=$CI_USER; pw=${CI_PW:?CI_PW is not set (db/run.sh sets it)} ;;
  ACDC)  who=ACDC; pw=${ACDC_PW:?ACDC_PW is not set (db/run.sh sets it)} ;;
  *)     who="${CI_USER}[$login]"; pw=${CI_PW:?CI_PW is not set (db/run.sh sets it)} ;;
esac
log=$(mktemp)
{
  echo "whenever sqlerror exit failure rollback"
  echo "whenever oserror exit failure rollback"
  printf 'set cloudconfig %s\n' "$WALLET"
  printf 'connect %s/"%s"@%s\n' "$who" "$pw" "$VAL_DB_SERVICE"
  [ "$mode" = check ] || echo "whenever sqlerror continue"
  echo "set serveroutput on size unlimited"
  for kv in "$@"; do printf 'define %s = "%s"\n' "${kv%%=*}" "${kv#*=}"; done
  echo "@$file"
  echo "exit"
} | "$SQL" -S /nolog 2>&1 | tee "$log"     # live output (long installs show their progress)
rc=${PIPESTATUS[1]}
if [ "$mode" = check ] && grep -qE '^(SP2-|Error starting at)|compilation errors' "$log"; then
  echo "ERROR $(basename "$file") as $login: $(grep -m1 -E '^(SP2-|ORA-|PLS-|Error starting at)|compilation errors' "$log")"
  rc=1
fi
rm -f "$log"
exit "$rc"
