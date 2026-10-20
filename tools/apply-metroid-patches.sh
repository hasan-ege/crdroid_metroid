#!/bin/sh
# Cherry-picks fuad00's metroid commits (tools/metroid-patches.json) onto crDroid's forks,
# each on a local branch "metroid". Stops at the first conflict and says where.
#
#   tools/apply-metroid-patches.sh [source dir]     (default: /home/hasan/android/crdroid)
#
# Re-running is safe: commits already present (same subject on the branch) are skipped.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
top=${1:-/home/hasan/android/crdroid}
json="$here/tools/metroid-patches.json"

export GIT_AUTHOR_NAME=${GIT_AUTHOR_NAME:-hasan} GIT_COMMITTER_NAME=${GIT_COMMITTER_NAME:-hasan}
export GIT_AUTHOR_EMAIL=${GIT_AUTHOR_EMAIL:-hasan@localhost} GIT_COMMITTER_EMAIL=${GIT_COMMITTER_EMAIL:-hasan@localhost}

list=$(mktemp)
trap 'rm -f "$list"' EXIT
python3 -I -c '
import json, sys
for r in json.load(open(sys.argv[1])):
    print(r["path"], r["repo"], r["branch"], r["ahead"], " ".join(c["sha"] for c in r["commits"]))
' "$json" > "$list"

# Read from a file, not a pipe: an exit inside a piped loop would only leave the subshell.
while read -r path repo branch ahead shas; do
    echo "== $path"
    cd "$top/$path"
    git checkout -q -B metroid
    git fetch -q --depth=$((ahead + 2)) "https://github.com/fuad00/$repo" "$branch"
    for sha in $shas; do
        subject=$(git log -1 --format=%s "$sha")
        if git log --format=%s -n 200 | grep -qxF "$subject"; then
            echo "   skip $sha (already applied)"
            continue
        fi
        if git cherry-pick -x "$sha" >/dev/null 2>&1; then
            echo "   ok   ${sha%"${sha#??????????}"} $subject"
        else
            echo "   CONFLICT ${sha%"${sha#??????????}"} $subject" >&2
            git status --short | sed 's/^/      /' >&2
            echo "   resolve in $top/$path, then: git cherry-pick --continue; re-run this script" >&2
            exit 1
        fi
    done
done < "$list"
echo "all metroid patches applied"
