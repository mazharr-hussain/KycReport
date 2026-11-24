#!/bin/bash
# Pipeline step 9.2a - the release PR carries its own generated files (main accepts pull requests only, so nothing is
# pushed to main by itself; I-084):
#   - SOURCE-MAP.json in step with the files (checks/source_map.py), then COMMON's build: db/deploy (install / upgrade
#     scripts, dependency map) and docs/components/*/technical.md
# When something differs, one commit is pushed to the PR branch with a person's token (GH_TOKEN), so the pipeline runs
# again on it: the version fingerprint is the same (job 1 builds these files anyway), so that run reuses the deployed
# database and merges. A head that is already such a commit is not carried again (no loop).
# Usage: carry.sh <pr branch> <tested head sha> <out file>   (env GH_TOKEN, GH_REPO; run from the repository root)
# Writes "carried" or "nothing" to <out file>; exit 1 when the push fails.
set -euo pipefail
branch=${1:?pr branch}; sha=${2:?head sha}; out=${3:?out file}
root=$(pwd); wt=$(mktemp -d)
auth="AUTHORIZATION: basic $(printf 'x-access-token:%s' "${GH_TOKEN:?GH_TOKEN is not set}" | base64 -w0)"
mark="Pipeline: generated files"
git -c http.extraheader="$auth" fetch -q origin "$branch"
if [ "$(git rev-parse FETCH_HEAD)" != "$sha" ]; then
  echo "::error::the PR branch moved since the tested commit ${sha:0:7} - nothing carried, not merged"; exit 1
fi
if git log -1 --format=%s "$sha" | grep -qF "$mark"; then echo nothing > "$out"; echo "the head is the carried commit"; exit 0; fi
# a full tree even when job 9 has a sparse checkout (a PR that does not touch COMMON)
git -c core.sparseCheckout=false worktree add -q --detach "$wt" "$sha"
cd "$wt"
python3 repos/common/deployment/checks/source_map.py
bash repos/common/build.sh > /dev/null
git add -A repos/common/SOURCE-MAP.json repos/common/db/deploy repos/common/docs/components
if git diff --cached --quiet; then
  echo nothing > "$out"; echo "the generated files are up to date"
else
  git diff --cached --stat | tail -1
  git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
      commit -q -m "$mark (step 9.2a, tested ${sha:0:7})"
  git -c http.extraheader="$auth" push -q origin "HEAD:refs/heads/$branch"
  echo carried > "$out"; echo "carried to $branch: $(git log -1 --format=%h)"
fi
cd "$root"; git worktree remove --force "$wt"
