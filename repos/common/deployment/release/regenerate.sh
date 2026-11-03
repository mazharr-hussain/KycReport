#!/bin/bash
# Commits the generated files of COMMON to main after a merge (job 7.2, and generated-files.yml for a push to main made
# by a person): SOURCE-MAP.json in step with the files (checks/source_map.py), then the build's generated files -
# db/deploy (install / upgrade scripts, dependency map) and docs/components/*/technical.md. Nobody commits them by hand;
# a PR's own run deploys what job 1 built from its source (the db/deploy artifact).
# Usage: regenerate.sh [ref]   (default origin/main; env GH_TOKEN, GH_REPO; run from the repository root)
# Nothing to commit -> nothing pushed. Its push is made with the workflow token, so it starts no other workflow.
set -euo pipefail
ref=${1:-origin/main}
root=$(pwd); wt=$(mktemp -d)
auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${GH_TOKEN:?GH_TOKEN is not set}" | base64 -w0)"
git -c http.extraheader="$auth" fetch -q origin main
git worktree add -q --detach "$wt" "$ref"
cd "$wt"
python3 repos/common/deployment/checks/source_map.py
bash repos/common/build.sh > /dev/null
git add -A repos/common/SOURCE-MAP.json repos/common/db/deploy repos/common/docs/components
if git diff --cached --quiet; then
  echo "generated files are up to date"
else
  git diff --cached --stat | tail -1
  git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit -q -m "COMMON: generated files (SOURCE-MAP, db/deploy, technical docs) after $(git log -1 --format=%h "$ref")"
  git -c http.extraheader="$auth" push -q origin HEAD:main
  echo "generated files committed to main: $(git log -1 --format=%h)"
fi
cd "$root"; git worktree remove --force "$wt"
