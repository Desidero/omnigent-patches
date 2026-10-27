#!/usr/bin/env bash
# Publish a build: force-update the fork's custom branch, push an immutable
# tag, push the server image and create the GitHub release on the fork.
#
#   release/publish.sh <out-dir> <built-commit>
#
# <out-dir> is the install set release/build.sh wrote (with plan.env from
# release/plan.py); <built-commit> is the tip build-custom.sh just rebuilt in
# ./omnigent, which must equal the install set's commit. Environment:
#   DRY_RUN=true   print the pushes, tag, image push and release instead
#   PRERELEASE     true (default) marks the release as a pre-release
#   FORK_REPO, FORK_TOKEN (contents + workflows write on the fork)
#   GHCR_TOKEN, GHCR_USER for ghcr.io
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$1" built="$2"
repo="${OMNIGENT_CLONE:-omnigent}"
dry_run="${DRY_RUN:-true}"
prerelease="${PRERELEASE:-true}"
fork="${FORK_REPO:-Desidero/omnigent}"

# shellcheck disable=SC1091
. "$out/build.env"
resume=""
# shellcheck disable=SC1091
[[ ! -f "$out/plan.env" ]] || . "$out/plan.env"

summary() { echo "$*"; [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || echo "$*" >> "$GITHUB_STEP_SUMMARY"; }
run() {
  if [[ "$dry_run" == true ]]; then
    summary "- dry run, would run: \`$*\`"
  else
    "$@"
  fi
}
die() { echo "::error::$*" >&2; exit 1; }

[[ "$built" == "$CUSTOM_COMMIT" ]] \
  || die "rebuilt custom $built differs from the install set's $CUSTOM_COMMIT"
[[ "$TAG" == custom/* ]] || die "$TAG is not a release tag; was the plan step skipped?"
mode=""
[[ "$dry_run" != true ]] || mode=", dry run"
summary "### Publish $TAG ($VERSION)${resume:+, resuming}$mode"
summary ""

export GIT_COMMITTER_NAME="${CUSTOM_COMMITTER_NAME:-github-actions[bot]}"
export GIT_COMMITTER_EMAIL="${CUSTOM_COMMITTER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
fork_url="https://github.com/$fork.git"
auth=()
if [[ -n "${FORK_TOKEN:-}" ]]; then
  basic="$(printf 'x-access-token:%s' "$FORK_TOKEN" | base64 -w0)"
  echo "::add-mask::$basic"
  auth=(-c "http.https://github.com/.extraheader=AUTHORIZATION: basic $basic")
fi

# 1. The fork's custom branch: CI-owned, rebuilt from the series.
old_custom="$(git ls-remote "$fork_url" refs/heads/custom | cut -f1)"
if [[ "$old_custom" == "$CUSTOM_COMMIT" ]]; then
  summary "- custom is already ${CUSTOM_COMMIT:0:12}"
else
  summary "- custom: ${old_custom:0:12} -> ${CUSTOM_COMMIT:0:12}"
  run git "${auth[@]}" -C "$repo" push --quiet \
    "--force-with-lease=refs/heads/custom:$old_custom" "$fork_url" "$CUSTOM_COMMIT:refs/heads/custom"
fi

# 2. The tag: annotated, never moved. plan.py recognises a re-run by Patches-Commit.
if [[ -n "$resume" ]]; then
  summary "- tag $TAG already exists for this build"
else
  message="Omnigent $VERSION

Built from $PATCHES_REPO@$PATCHES_COMMIT onto ${UPSTREAM_REPO:-omnigent-ai/omnigent}@$OSS_COMMIT.

Build-Id: $BUILD_ID
OSS-Commit: $OSS_COMMIT
Patches-Commit: $PATCHES_COMMIT
Image: $IMAGE"
  git -C "$repo" tag -a "$TAG" "$CUSTOM_COMMIT" -m "$message"
  summary "- tag $TAG on ${CUSTOM_COMMIT:0:12}"
  run git "${auth[@]}" -C "$repo" push --quiet "$fork_url" "refs/tags/$TAG"
fi

# 3. The server image on GHCR.
if [[ "$dry_run" == true ]]; then
  summary "- dry run, would push the image \`$IMAGE\`"
else
  printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin >/dev/null
  if [[ -n "$resume" ]] && digest="$(docker buildx imagetools inspect "$IMAGE" --format '{{.Manifest.Digest}}' 2>/dev/null)"; then
    summary "- image $IMAGE already pushed ($digest)"
  else
    "$here/release/build-image.sh" "$out" --push --digest-file "$out/digest"
    digest="$(cat "$out/digest")"
    summary "- pushed $IMAGE ($digest)"
  fi
  python3 -I "$here/release/notes.py" set-digest --manifest "$out/release/manifest.json" \
    --notes "$out/notes.md" --digest "$digest"
fi

# 4. The GitHub release with the install set.
args=(release create "$TAG" -R "$fork" --verify-tag --title "$TAG ($VERSION)" --notes-file "$out/notes.md")
if [[ "$prerelease" == true ]]; then args+=(--prerelease); else args+=(--latest); fi
mapfile -t assets < <(find "$out/release" -maxdepth 1 -type f ! -name '.*' | sort)
if [[ "$dry_run" != true ]] && GH_TOKEN="$FORK_TOKEN" gh release view "$TAG" -R "$fork" >/dev/null 2>&1; then
  summary "- release $TAG already exists; not changing it"
else
  summary "- release $TAG with ${#assets[@]} assets$([[ "$prerelease" == true ]] && echo ", pre-release")"
  if [[ "$dry_run" == true ]]; then
    run gh "${args[@]}" "${assets[@]##*/}"
  else
    GH_TOKEN="$FORK_TOKEN" gh "${args[@]}" "${assets[@]}"
    summary "- https://github.com/$fork/releases/tag/$TAG"
  fi
fi
