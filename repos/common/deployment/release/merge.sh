#!/bin/bash
# Pipeline step 7.2 - merge the PR that passed every job (runs only after the job-9 gate), then publish its release.
#   - label "hold" on the PR: not merged (the PR stays open for a person to merge)
#   - a draft PR is marked ready for review first
#   - merged as a merge commit ("Merge pull request #n ...") and only if its head is still the tested commit
#   - the release is published here (release/publish.sh): a merge made with the workflow token starts no other workflow
#   - then the generated files are committed to main (release/regenerate.sh)
# Usage: merge.sh <pr number> <tested head sha> <out file>   (env: GH_TOKEN, GH_REPO; run from the repository root)
# Writes one line to <out file> for the PR comment. Exit 1 only when GitHub refuses the merge.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
pr=${1:?pr number}; sha=${2:?head sha}; out=${3:?out file}
if gh pr view "$pr" --json labels -q '.labels[].name' | grep -qx hold; then
  echo "The PR has the label **hold**, so it was not merged: remove the label and re-run job 7, or merge it by hand." | tee "$out"
  exit 0
fi
if [ "$(gh pr view "$pr" --json isDraft -q .isDraft)" = true ]; then
  gh pr ready "$pr" || { echo "Could not mark the draft PR ready for review - merge it by hand." | tee "$out"; exit 1; }
fi
if ! gh pr merge "$pr" --merge --match-head-commit "$sha"; then
  echo "GitHub refused the merge (see step 7.2 in the run) - the PR stays open; merge it by hand." | tee "$out"
  exit 1
fi
merged=$(gh pr view "$pr" --json mergeCommit -q .mergeCommit.oid)
echo "Merged by the pipeline (commit ${merged:0:7})." | tee "$out"
bash "$HERE/publish.sh" "$pr" "$merged"
# the generated files of the merged source (SOURCE-MAP, db/deploy, technical docs) - a PR that touches COMMON only
if [ "${COMMON:-true}" = true ]; then
  bash "$HERE/regenerate.sh" "$merged" || echo "::warning::the generated files were not committed - generated-files.yml can be run by hand"
fi
