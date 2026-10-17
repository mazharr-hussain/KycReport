#!/bin/sh
# Builds the common application with the one COMMON build (no build logic here): common/build.sh [--release N]
exec python3 "$(dirname "$0")/tools/build.py" --repo common "$@"
