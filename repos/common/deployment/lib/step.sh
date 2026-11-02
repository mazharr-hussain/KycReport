#!/bin/bash
# Shared by the COMMON deployment runners: step <name> <command...> runs one step, keeps its log in LOG_DIR/<name>.log
# and, on failure, records the step name in LOG_DIR/failed (read by the error-handling job) and stops the job.
# Every step result is also written to the job summary page.
LOG_DIR=${LOG_DIR:-${RUNNER_TEMP:-/tmp}/common-logs}
mkdir -p "$LOG_DIR"
step() {
  local name=$1; shift
  echo "::group::$name"
  if "$@" 2>&1 | tee "$LOG_DIR/$name.log"; [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo "::endgroup::"; echo "PASS $name"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- PASS \`$name\`" >> "$GITHUB_STEP_SUMMARY"; fi
  else
    echo "::endgroup::"; echo "::error::$name failed"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- **FAIL \`$name\`**" >> "$GITHUB_STEP_SUMMARY"; fi
    echo "$name" > "$LOG_DIR/failed"
    exit 1
  fi
}
