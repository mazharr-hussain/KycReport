#!/bin/bash
# Shared by the COMMON deployment runners: step <name> <command...> runs one step, keeps its log in LOG_DIR/<name>.log
# and, on failure, records the step name in LOG_DIR/failed (read by the error-handling job) and stops the job - or,
# with KEEP_GOING=1, goes on with the next step (finish then fails the job when any step failed: every failure of
# the job is reported together, in one PR comment).
# Every step result is also written to the job summary page, with the time it took; LOG_DIR/timings keeps
# "<step> <seconds> <PASS|FAIL>" per step for the PR comment's step-time table (checks/report.py).
LOG_DIR=${LOG_DIR:-${RUNNER_TEMP:-/tmp}/common-logs}
mkdir -p "$LOG_DIR"
step() {
  local name=$1 t0 secs; shift
  t0=$(date +%s)
  echo "::group::$name"
  if "$@" 2>&1 | tee "$LOG_DIR/$name.log"; [ "${PIPESTATUS[0]}" -eq 0 ]; then
    secs=$(( $(date +%s) - t0 )); echo "$name $secs PASS" >> "$LOG_DIR/timings"
    echo "::endgroup::"; echo "PASS $name (${secs}s)"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- PASS \`$name\` (${secs}s)" >> "$GITHUB_STEP_SUMMARY"; fi
  else
    secs=$(( $(date +%s) - t0 )); echo "$name $secs FAIL" >> "$LOG_DIR/timings"
    echo "::endgroup::"; echo "::error::$name failed (${secs}s)"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "- **FAIL \`$name\`** (${secs}s)" >> "$GITHUB_STEP_SUMMARY"; fi
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
