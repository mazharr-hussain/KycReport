#!/bin/bash
# Shared by the COMMON deployment runners: step <name> <command...> runs one step, keeps its log in LOG_DIR/<name>.log,
# and on failure records the step name in LOG_DIR/failed (read by the pipeline to open the issue) and stops.
LOG_DIR=${LOG_DIR:-${RUNNER_TEMP:-/tmp}/common-logs}
mkdir -p "$LOG_DIR"
step() {
  local name=$1; shift
  echo "::group::$name"
  if "$@" 2>&1 | tee "$LOG_DIR/$name.log"; [ "${PIPESTATUS[0]}" -eq 0 ]; then
    echo "::endgroup::"; echo "PASS $name"
  else
    echo "::endgroup::"; echo "::error::$name failed"
    echo "$name" > "$LOG_DIR/failed"
    exit 1
  fi
}
