#!/bin/sh
# Builds the kyc application with the one COMMON build (no build logic here): kyc/build.sh [--release N]
exec python3 "$(dirname "$0")/../common/tools/build.py" --repo kyc "$@"
