#!/bin/sh
# Runs one SQL file on the validation database (#192) with SQLcl: valdb.sh <user> <password> <sql-file> [check]
# Needs SQL (SQLcl binary), WALLET (wallet zip path) and VAL_DB_SERVICE. With "check" (install steps) the run stops at
# the first SQL error and fails on SP2- errors or code compiled with errors; without it (tests) everything runs.
user=$1; pw=$2; file=$3; mode=$4
tmp=$(mktemp); log=$(mktemp)
{
  echo "whenever sqlerror exit failure"
  echo "whenever oserror exit failure"
  echo "set cloudconfig $WALLET"
  printf 'connect %s/"%s"@%s\n' "$user" "$pw" "$VAL_DB_SERVICE"  # printf: echo in sh would change a \ in the password
  [ "$mode" = check ] || echo "whenever sqlerror continue"
  echo "set serveroutput on size unlimited"
  echo "@$file"
  echo "exit"
} > "$tmp"
"$SQL" -S /nolog @"$tmp" > "$log" 2>&1
rc=$?
cat "$log"
rm -f "$tmp"
[ "$mode" = check ] || exit $rc
if grep -qE '^(SP2-|Error starting at)|compilation errors' "$log"; then
  echo "::error::$(basename "$file") as $user: $(grep -m1 -E '^(SP2-|ORA-|PLS-|Error starting at)|compilation errors' "$log")"
  rc=1
fi
exit $rc
