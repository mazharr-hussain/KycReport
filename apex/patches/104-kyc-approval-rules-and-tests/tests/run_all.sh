#!/bin/bash
# Release 76 (T-01, T-04): runs the KYC tests in a fixed order on the local test database.
#   0. common_test_fixtures.sql as XXFUSION (release 93: COMMON states without a COMMON routine yet; connection name
#      xxfusion_local, e.g. sql -save xxfusion_local -savepwd xxfusion/<password>@<host>:<port>/<service>)
#   1. test_users.sql (every test user, idempotent)
#   2. the database tests (security and workflow first: they add the test data the others read)
#   3. a warm-up request per application (the first page after an import is slow; browser tests no longer time out)
#   4. the browser tests
# Usage: SQLCL=<sqlcl> HOST=http://localhost:8080 apex/tests/run_all.sh [db|ui]   (connection name kyc_local)
cd "$(dirname "$0")/../.."
SQLCL=${SQLCL:-sql}
HOST=${HOST:-http://localhost:8080}
export SQLCL
db() { printf "@apex/tests/%s.sql\nexit\n" "$1" | $SQLCL -S -name kyc_local 2>&1 | grep -v JAVA_TOOL; }
if [ "$1" != "ui" ]; then
    echo "== test fixtures (XXFUSION)"
    printf "@apex/tests/common_test_fixtures.sql\nexit\n" | $SQLCL -S -name xxfusion_local 2>&1 | grep -v JAVA_TOOL | grep -i "error\|ORA-"
    echo "== test users"; db test_users | grep -i "error\|ORA-"
    for t in security_test workflow_test kyc_flow_test party_test request_party_test token_test \
             r73_kyc_test r74_kyc_test r74_party_test r74_case_test r74_email_test r74_risk_test r74_perf_test \
             r75_kyc_test r76_kyc_test monitoring_test kyc87_adapt_test kyc88_shared_test kyc89_rfi_test kyc90_cleanup_test kyc91_unused_test kyc92_retire_test; do
        out=$(db $t)
        echo "== $t: $(grep -c '^PASS' <<<"$out") pass, $(grep -c '^FAIL' <<<"$out") fail"
        grep -E '^FAIL|ORA-' <<<"$out" | head -5
    done
fi
if [ "$1" != "db" ]; then
    echo "== warm-up"
    for app in kyc common; do curl -s -o /dev/null -m 120 -w "$app %{http_code} %{time_total}s\n" "$HOST/ords/r/xxcus/$app/login"; done
    for t in kyc_ui party_ui request_party_ui r74_party_ui r74_case_ui r74_email_ui r74_risk_ui r75_ui kyc88_shared_ui kyc89_rfi_ui; do
        echo "== $t"; timeout 1500 python3 apex/tests/$t.py 2>&1 | grep -E 'FAIL|passed|Error' | tail -4
    done
fi
