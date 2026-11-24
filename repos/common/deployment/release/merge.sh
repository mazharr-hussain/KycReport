#!/bin/bash
# Pipeline step 9.2 - merge the PR that passed every job (runs only after the job-9 gate). Merging is all it does
# (I-084): what follows a merge - the release, the generated files, the docs - is done once, by after-merge.yml.
#   - label "hold" on the PR: not merged (the PR stays open for a person to merge)
#   - a draft PR is marked ready for review first
#   - merged as a merge commit ("Merge pull request #n ...") and only if its head is still the tested commit
#   - after-merge.yml starts on the push to main (a person's merge or a person's token) or, for a merge made with the
#     workflow token (which starts no workflow), on this pipeline run's completion
# Usage: merge.sh <pr number> <tested head sha> <out file>   (env: GH_TOKEN, GH_REPO; run from the repository root)
# Writes one line to <out file> for the PR comment. Exit 1 only when GitHub refuses both the merge and auto-merge.
set -uo pipefail
pr=${1:?pr number}; sha=${2:?head sha}; out=${3:?out file}
if gh pr view "$pr" --json labels -q '.labels[].name' | grep -qx hold; then
  echo "The PR has the label **hold**, so it was not merged: remove the label and re-run job 9, or merge it by hand." | tee "$out"
  exit 0
fi
if [ "$(gh pr view "$pr" --json isDraft -q .isDraft)" = true ]; then
  gh pr ready "$pr" || { echo "Could not mark the draft PR ready for review - merge it by hand." | tee "$out"; exit 1; }
fi
if ! gh pr merge "$pr" --merge --match-head-commit "$sha"; then
  # the required check is this job ("9 Finalize the PR"): while it runs, the branch rule refuses a direct merge.
  # Auto-merge instead: GitHub merges the tested head as soon as this job has passed (after-merge.yml then publishes
  # the release)
  if gh pr merge "$pr" --auto --merge --match-head-commit "$sha"; then
    echo "Auto-merge is on: GitHub merges this PR when the check \"9 Finalize the PR\" has passed (the release stays a draft, I-091)." | tee "$out"
    exit 0
  fi
  echo "GitHub refused the merge and auto-merge (see step 9.2 in the run) - the PR stays open; merge it by hand." | tee "$out"
  exit 1
fi
merged=$(gh pr view "$pr" --json mergeCommit -q .mergeCommit.oid)
echo "Merged by the pipeline (commit ${merged:0:7}); the release stays a draft (I-091)." | tee "$out"
