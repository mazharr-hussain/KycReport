#!/bin/bash
# A stand-in for SQLcl for the dry run (checks/dryrun.sh): no database. It reads the script lib/sql.sh sends on stdin,
# logs "<script> <login>" to STUB_LOG and answers the pipeline's questions from STUB_DIR:
#   STUB_DIR/record   the deployed.sql "get" output (no file: nothing recorded)
#   STUB_PASSED=1     a check passed before (PASSED-BEFORE)         STUB_DROP=1   a test session ends early
in=$(cat)
file=$(printf '%s\n' "$in" | sed -n 's/^@//p' | tail -1 | tr -d '"')
login=$(printf '%s\n' "$in" | sed -n 's#^connect \([^/]*\)/.*#\1#p')
def() { printf '%s\n' "$in" | sed -n "s/^define $1 = \"\\(.*\\)\"$/\\1/p"; }
echo "$(basename "$file") $login" >> "${STUB_LOG:?}"
body=$(cat "$file" 2>/dev/null)
case $(basename "$file") in
  deployed.sql)  [ "$(def mode)" = get ] && [ -f "$STUB_DIR/record" ] && cat "$STUB_DIR/record" ;;
  dependencies.sql) echo 'NAME,TYPE,REFERENCED_NAME,REFERENCED_TYPE' > "$(def out)" ;;
  sert-eval.sql) echo "SERT 0 findings" ;;
  *)
    case $body in *SERT_EVAL*) echo "SERT_EVAL 1" ;; esac
    case $body in *"apex validate"*) echo "Validation successful"; echo "Import successful" ;; esac
    case $body in *"'BASELINE '"*) echo "BASELINE 1" ;; esac
    case $body in *PASSED-BEFORE*) [ "${STUB_PASSED:-0}" = 1 ] && echo "PASSED-BEFORE" ;; esac
    case $body in *"'DEP '"*) echo "DEP XXFND_CALLER_PKG" ;; esac
    case $body in *"apex export"*) d=$(printf '%s' "$body" | grep -o -- '-dir [^ ]*' | cut -c6-); mkdir -p "$d/f135"
                                   echo app > "$d/f135/application.apx" ;; esac
    # a test session: one "== <file>" line per test file it runs, then a passing check
    n=$(printf '%s\n' "$body" | grep -c '^prompt == ')
    printf '%s\n' "$body" | sed -n 's/^prompt \(== .*\)/\1/p' | { if [ "${STUB_DROP:-0}" = 1 ] && [ "$n" -gt 1 ]; then head -n -1; else cat; fi; }
    [ "$n" -gt 0 ] && echo "PASS stub check" ;;
esac
exit 0
