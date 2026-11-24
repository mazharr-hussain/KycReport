#!/bin/bash
# Pipeline step 9.2 - merge the PR that passed every job (runs only after the job-9 gate). Merging is all it does
# (I-084): what follows a merge - the release, the generated files, the docs - is done once, by after-merge.yml.
#   - label "hold" on the PR: not merged (the PR stays open for a person to merge)
#   - a draft PR is marked ready for review first
#   - merged as a merge commit ("Merge pull request #n ...") and only if its head is still the tested commit
#   - run with a person's token (step 9.2b: PIPELINE_MERGE_TOKEN or ADD_TO_PROJECT_PAT): auto-merge turned on as that
#     person makes the merge theirs, so GitHub closes the PR's "Fixes #n" issues (I-087) and the push to main starts
#     after-merge.yml (which publishes nothing, I-091); with the workflow token the issues stay open
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
  # the person's token refused (e.g. a classic token without the workflow scope on a PR that changes workflow files):
  # the workflow token turns auto-merge on instead - the PR's "Fixes #n" issues then stay open (close them by hand)
  if [ -n "${FALLBACK_TOKEN:-}" ] && [ "$FALLBACK_TOKEN" != "$GH_TOKEN" ] && \
     GH_TOKEN=$FALLBACK_TOKEN gh pr merge "$pr" --auto --merge --match-head-commit "$sha"; then
    echo "Auto-merge is on (workflow token - its \"Fixes #n\" issues stay open: close them by hand after the merge)." | tee "$out"
    exit 0
  fi
  echo "GitHub refused the merge and auto-merge (see step 9.2 in the run) - the PR stays open; merge it by hand." | tee "$out"
  exit 1
fi
merged=$(gh pr view "$pr" --json mergeCommit -q .mergeCommit.oid)
echo "Merged by the pipeline (commit ${merged:0:7}); the release stays a draft (I-091)." | tee "$out"
