#!/bin/bash
# Shared by the COMMON deployment runners: step <name> <command...> runs one step, keeps its log in LOG_DIR/<name>.log
# and, on failure, records the step name in LOG_DIR/failed (read by the error-handling job) and stops the job - or,
# with KEEP_GOING=1, goes on with the next step (finish then fails the job when any step failed: every failure of
# the job is reported together, in one PR comment).
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
    echo "$name" >> "$LOG_DIR/failed"
    [ "${KEEP_GOING:-}" = 1 ] && return 1
    exit 1
  fi
}
finish() {   # KEEP_GOING jobs: fail when any step failed
  if [ -s "$LOG_DIR/failed" ]; then
    echo "::error::failed steps: $(tr '\n' ' ' < "$LOG_DIR/failed")"; exit 1
  fi
}
