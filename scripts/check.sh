#!/usr/bin/env bash
# Apply the series onto BASE in a throwaway worktree and check the result.
#
#   scripts/check.sh [--repo <omnigent-clone>] [--custom <ref>] [--report]
#
# Besides applying cleanly, every patch must carry usage docs (touch a path in
# DOC_PATHS) or a "Docs: none (<reason>)" trailer, every "# series:" needs a
# "## <series>" section in docs/custom/README.md of the applied tree, and the
# last series must be custom-docs-index, the commit that holds that index.
#
# --repo     Omnigent clone that has the BASE commit (default: $OMNIGENT_REPO).
# --custom   Also require the applied tree to equal <ref>'s tree. Defaults to
#            "custom" when that ref exists in the clone.
# --report   Post the result as a commit status on the custom ref's commit with
#            `gh api repos/<owner>/<repo>/statuses/<sha>`. The repo comes from
#            $REPORT_REPO (default Desidero/omnigent), the context from
#            $REPORT_CONTEXT (default patches/apply), and $REPORT_URL, if set,
#            becomes the status link. Needs gh logged in with commit-status write.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="${OMNIGENT_REPO:-}"
custom_ref=""
report=0

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --custom) custom_ref="$2"; shift 2 ;;
    --report) report=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done
if [[ -z "$repo" ]]; then
  echo "error: pass --repo <omnigent clone> or set OMNIGENT_REPO" >&2
  exit 2
fi
repo="$(cd "$repo" && pwd)"

# Paths that count as usage docs: upstream's user and agent docs, feature-map
# recipes, design docs (the telemetry variable table) and the server API reference.
DOC_PATHS_RE='^(docs/|feature-map/|designs/|omnigent/server/API\.md$)'
INDEX_SERIES=custom-docs-index
INDEX_PATH=docs/custom/README.md

base="$(tr -d '[:space:]' < "$here/patches/BASE")"
mapfile -t patches < <(grep -v -e '^#' -e '^[[:space:]]*$' "$here/patches/series")
if [[ -z "$custom_ref" ]] && git -C "$repo" rev-parse --verify --quiet custom >/dev/null; then
  custom_ref=custom
fi
custom_sha=""
if [[ -n "$custom_ref" ]]; then
  custom_sha="$(git -C "$repo" rev-parse --verify "$custom_ref^{commit}")"
fi

# Commit identity for `git am` on machines (CI) that have none configured.
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-patches-check}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-patches-check@localhost}"

work="$(mktemp -d)/apply"
cleanup() {
  git -C "$repo" worktree remove --force "$work" >/dev/null 2>&1 || true
  rm -rf "$(dirname "$work")"
}
trap cleanup EXIT

state=failure
message=""
finish() {
  echo "$message"
  if [[ "$report" == 1 ]]; then
    if [[ -z "$custom_sha" ]]; then
      echo "error: --report needs a custom ref to attach the status to" >&2
      exit 2
    fi
    args=(-f "state=$state" -f "context=${REPORT_CONTEXT:-patches/apply}"
      -f "description=${message:0:140}")
    [[ -n "${REPORT_URL:-}" ]] && args+=(-f "target_url=$REPORT_URL")
    gh api --method POST "repos/${REPORT_REPO:-Desidero/omnigent}/statuses/$custom_sha" \
      "${args[@]}" >/dev/null
    echo "reported $state on ${REPORT_REPO:-Desidero/omnigent}@$custom_sha"
  fi
  [[ "$state" == success ]]
}

# Docs rule, per patch file: it touches a doc path or says why it needs none.
patch_message() {
  # The commit message: after the mail headers, up to the diffstat separator.
  awk 'body && /^---$/ {exit} body {print} !body && /^$/ {body=1}' "$1"
}
docs_problems=()
for patch in "${patches[@]}"; do
  file="$here/patches/$patch"
  [[ -f "$file" ]] || continue
  if grep -E '^diff --git a/' "$file" | sed -E 's|^diff --git a/(.*) b/.*$|\1|' \
      | grep -qE "$DOC_PATHS_RE"; then
    continue
  fi
  if patch_message "$file" | git interpret-trailers --parse | grep -q '^Docs: none ('; then
    continue
  fi
  docs_problems+=("$patch has no usage docs and no 'Docs: none (<reason>)' trailer")
done
mapfile -t series_names < <(sed -nE 's/^#[[:space:]]*series:[[:space:]]*([^[:space:]]+).*$/\1/p' \
  "$here/patches/series" | awk '!seen[$0]++')
last_series="$(sed -nE 's/^#[[:space:]]*series:[[:space:]]*([^[:space:]]+).*$/\1/p' \
  "$here/patches/series" | tail -n 1)"
if [[ "$last_series" != "$INDEX_SERIES" ]]; then
  docs_problems+=("the last series is ${last_series:-missing}, not $INDEX_SERIES")
fi
if [[ ${#docs_problems[@]} -gt 0 ]]; then
  printf '%s\n' "${docs_problems[@]}" >&2
  message="docs check failed: ${docs_problems[0]}"
  finish || exit 1
fi

git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null || {
  message="BASE $base is not in $repo; fetch it first"
  finish || exit 1
}
git -C "$repo" worktree add --quiet --detach "$work" "$base"

applied=0
for patch in "${patches[@]}"; do
  if ! git -C "$work" am -3 --quiet "$here/patches/$patch" >/dev/null 2>"$work.err"; then
    cat "$work.err" >&2
    git -C "$work" am --abort >/dev/null 2>&1 || true
    message="$patch did not apply after $applied of ${#patches[@]} patches"
    finish || exit 1
  fi
  applied=$((applied + 1))
done

# Quick sanity: no conflict markers, and changed Python and JSON files parse.
mapfile -t changed < <(git -C "$work" diff --name-only --diff-filter=AM "$base" HEAD)
problems=()
for path in "${changed[@]}"; do
  file="$work/$path"
  if grep -qE '^(<<<<<<<|>>>>>>>) ' "$file"; then
    problems+=("conflict marker in $path")
  fi
  case "$path" in
    *.py) python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], "rb").read(), sys.argv[1])' \
            "$file" 2>/dev/null || problems+=("Python syntax error in $path") ;;
    *.json) python3 -m json.tool "$file" >/dev/null 2>&1 || problems+=("invalid JSON in $path") ;;
  esac
done
if [[ ${#problems[@]} -gt 0 ]]; then
  printf '%s\n' "${problems[@]}" >&2
  message="sanity check failed: ${problems[0]}"
  finish || exit 1
fi

# Every series has a section in the index at the series tip.
if [[ -f "$work/$INDEX_PATH" ]]; then
  mapfile -t indexed < <(sed -nE 's/^##[[:space:]]+([^[:space:]]+)[[:space:]]*$/\1/p' "$work/$INDEX_PATH")
else
  indexed=()
fi
for name in "${series_names[@]}"; do
  if ! printf '%s\n' "${indexed[@]}" | grep -qxF -- "$name"; then
    problems+=("series $name has no '## $name' section in $INDEX_PATH")
  fi
done
if [[ ${#problems[@]} -gt 0 ]]; then
  printf '%s\n' "${problems[@]}" >&2
  message="index check failed: ${problems[0]}"
  finish || exit 1
fi

if [[ -n "$custom_sha" ]]; then
  applied_tree="$(git -C "$work" rev-parse 'HEAD^{tree}')"
  custom_tree="$(git -C "$repo" rev-parse "$custom_sha^{tree}")"
  if [[ "$applied_tree" != "$custom_tree" ]]; then
    git -C "$repo" diff --stat "$custom_sha" "$(git -C "$work" rev-parse HEAD)" >&2 || true
    message="$applied patches apply, but the tree differs from $custom_ref; re-run export.sh"
    finish || exit 1
  fi
  state=success
  message="$applied patches apply on ${base:0:12} and match $custom_ref"
else
  state=success
  message="$applied patches apply on ${base:0:12} (no custom ref to compare)"
fi
finish
