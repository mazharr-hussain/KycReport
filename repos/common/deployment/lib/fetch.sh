#!/bin/bash
# fetch.sh <url> <sha256> <file>: downloads a pinned tool and stops unless its SHA-256 matches (tools.env).
set -euo pipefail
url=$1; sum=$2; out=$3
curl -fsSL --retry 3 -o "$out" "$url"
echo "$sum  $out" | sha256sum -c --quiet - || { echo "ERROR checksum mismatch: $url"; rm -f "$out"; exit 1; }
