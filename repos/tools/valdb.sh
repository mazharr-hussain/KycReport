#!/bin/sh
# Runs one SQL file on the validation database (#192, #195) with SQLcl: valdb.sh <schema> <sql-file> [check]
# Signs in with the IDCS database token (no password): the global user CI_IAM connects through the schema (proxy),
# so the file runs as XXCUS or XXFUSION. Needs SQL (SQLcl), TNS_ADMIN (wallet folder with the alias "valtoken") and
# OCI_CONFIG (OCI CLI config with the session token). The database token lives 60 minutes: renewed after 40.
# With "check" (install steps) the run stops at the first SQL error and fails on SP2- errors or code compiled with
# errors; without it (tests) everything runs.
# DB_AUTH=password (for now, until the IDCS trust works): direct login with the wallet zip (WALLET) as ADMIN
# (ADMIN_PW) on VAL_DB_SERVICE; for XXCUS / XXFUSION as ADMIN[schema] (proxy - their passwords are random, unknown).
schema=$1; file=$2; mode=$3
if [ "$DB_AUTH" = password ]; then
  who=ADMIN; [ "$schema" = ADMIN ] || who="ADMIN[$schema]"
  login=$(printf 'set cloudconfig %s\nconnect %s/"%s"@%s' "$WALLET" "$who" "$ADMIN_PW" "$VAL_DB_SERVICE")
elif [ -z "$(find "$HOME/.oci/db-token" -name 'oci-db-token' -mmin -40 2>/dev/null)" ]; then
  oci iam db-token get --auth security_token --config-file "$OCI_CONFIG" > /dev/null || { echo "::error::no database token"; exit 1; }
fi
[ "$DB_AUTH" = password ] || login="connect [$schema]/@valtoken"
tmp=$(mktemp); log=$(mktemp)
{
  echo "whenever sqlerror exit failure"
  echo "whenever oserror exit failure"
  echo "$login"
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
  echo "::error::$(basename "$file") as $schema: $(grep -m1 -E '^(SP2-|ORA-|PLS-|Error starting at)|compilation errors' "$log")"
  rc=1
fi
exit $rc
