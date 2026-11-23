#!/bin/bash
# Publishes the GitHub Release of a merged application PR (used by release.yml on a merge to main, and by pipeline job 9.2
# right after it merges the PR - a merge made with the workflow token starts no other workflow).
#   - the PR title gives the release: "<APP> Release <N>: <summary>" -> tag <app>-<N> (issue #218)
#   - the draft release prepared by job 9.1 (APEXlang zip of the tested application + docs) is published, with the PR's
#     linked issues ("Fixes #n") as notes; no draft (KYC today): the zip committed in repos/<app>/releases/*_<N>.zip
# Usage: publish.sh <pr number> <merge commit sha>   (env: GH_TOKEN, GH_REPO; run from the repository root)
# Running it twice is harmless: a published release is left as it is.
set -euo pipefail
pr=${1:?pr number}; target=${2:?merge commit}
title=$(gh pr view "$pr" --json title -q .title)
app=$(printf '%s' "$title" | sed -nE 's/^(COMMON|KYC) Release [0-9]+: .+$/\1/p')
n=$(printf '%s' "$title" | sed -nE 's/^(COMMON|KYC) Release ([0-9]+): .+$/\2/p')
if [ -z "$n" ]; then echo "PR #$pr \"$title\" is not a release - nothing to publish"; exit 0; fi
lower=$(printf '%s' "$app" | tr '[:upper:]' '[:lower:]'); tag="$lower-$n"
notes=$(mktemp)
{ echo "## $title"; echo
  gh pr view "$pr" --json body -q .body | grep -iE '(fixes|closes|resolves) #[0-9]+' | sed 's/^/- /' || true
  echo; echo "Pull request: #$pr"; } > "$notes"
draft=$(gh release view "$tag" --json isDraft -q .isDraft 2>/dev/null || echo none)
case $draft in
  true)
    gh release edit "$tag" --draft=false --target "$target" --title "$title" --notes-file "$notes"
    echo "published $title (zip from the pipeline)" ;;
  false)
    echo "$title is already published" ;;
  *)
    zip=$(find "repos/$lower/releases" -maxdepth 1 -name "*_$n.zip" 2>/dev/null | head -1)
    if [ -z "$zip" ]; then echo "::notice::$title has no draft release and no committed zip - nothing published"; exit 0; fi
    gh release create "$tag" "$zip" --title "$title" --notes-file "$notes" --target "$target" \
      || gh release view "$tag" > /dev/null   # published meanwhile by the other caller
    echo "published $title (committed zip)" ;;
esac
rm -f "$notes"
