#!/bin/bash
# app-url.sh: prints the ORDS base URL of the validation database's APEX (https://<host>/ords), derived from the
# wallet's tnsnames.ora: an Autonomous Database service <prefix>_<db>_<level>.adb.oraclecloud.com on host
# adb.<region>.oraclecloud.com serves APEX at https://<prefix>-<db>.adb.<region>.oraclecloudapps.com/ords.
# VAL_APP_URL (repository variable) overrides it. Env: WALLET.
set -euo pipefail
if [ -n "${VAL_APP_URL:-}" ]; then echo "${VAL_APP_URL%/}"; exit 0; fi
tns=$(unzip -p "${WALLET:?WALLET is not set}" tnsnames.ora | tr -d ' \r\n' | tr '[:upper:]' '[:lower:]')
service=$(printf '%s' "$tns" | grep -oE 'service_name=[a-z0-9_]+\.adb\.oraclecloud\.com' | head -1 | cut -d= -f2)
region=$(printf '%s' "$tns" | grep -oE 'host=adb\.[a-z0-9-]+\.oraclecloud\.com' | head -1 | cut -d. -f2)
name=${service%%.adb.*}          # <prefix>_<db>_<level>
name=${name%_*}                  # <prefix>_<db>
[ -n "$name" ] && [ -n "$region" ] || { echo "ERROR cannot read the APEX URL from the wallet - set VAL_APP_URL" >&2; exit 1; }
echo "https://${name%%_*}-${name#*_}.adb.$region.oraclecloudapps.com/ords"
