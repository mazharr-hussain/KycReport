#!/bin/sh
# Runs one SQL file on the validation database with SQLcl: sql.sh <schema> <sql-file> [check]
# Login (environment "Oracle DB Dev"): the wallet zip WALLET and the ADMIN password ADMIN_PW on VAL_DB_SERVICE; for a
# schema other than ADMIN as ADMIN[schema] (proxy - the schema passwords are random and unknown). SQL = SQLcl binary.
# With "check" (install steps) the run stops at the first SQL error and fails on SP2- errors or code compiled with
# errors; without it (tests) everything runs.
schema=$1; file=$2; mode=$3
who=ADMIN; [ "$schema" = ADMIN ] || who="ADMIN[$schema]"
tmp=$(mktemp); log=$(mktemp)
{
  echo "whenever sqlerror exit failure"
  echo "whenever oserror exit failure"
  printf 'set cloudconfig %s\nconnect %s/"%s"@%s\n' "$WALLET" "$who" "$ADMIN_PW" "$VAL_DB_SERVICE"
  [ "$mode" = check ] || echo "whenever sqlerror continue"
  echo "set serveroutput on size unlimited"
  echo "@$file"
  echo "exit"
} > "$tmp"
"$SQL" -S /nolog @"$tmp" > "$log" 2>&1
rc=$?
cat "$log"
rm -f "$tmp"
if [ "$mode" = check ] && grep -qE '^(SP2-|Error starting at)|compilation errors' "$log"; then
  echo "ERROR $(basename "$file") as $schema: $(grep -m1 -E '^(SP2-|ORA-|PLS-|Error starting at)|compilation errors' "$log")"
  rc=1
fi
rm -f "$log"
exit $rc
