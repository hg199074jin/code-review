#!/bin/sh
# Materialize the six V2.3 Group F (DET) scenario workspaces from evals/fixtures/det/.
# Each workspace = git repo with the baseline committed and the changed files applied
# as the uncommitted working tree (the review scope).
#
# Usage: build-det-fixtures.sh <output-dir>
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:?usage: build-det-fixtures.sh <output-dir>}
mkdir -p "$OUT"
n=0
for d in det01 det02 det03 det04 det05 det06; do
  ws="$OUT/v23-$d"
  rm -rf "$ws"
  mkdir -p "$ws"
  cp "$HERE"/fixtures/det/$d/baseline/* "$ws"/
  git -C "$ws" init -q -b main
  git -C "$ws" add -A
  git -C "$ws" -c user.email=eval@local -c user.name=eval commit -qm baseline
  if [ -n "$(ls "$HERE/fixtures/det/$d/changed" 2>/dev/null)" ]; then
    cp "$HERE"/fixtures/det/$d/changed/* "$ws"/
  fi
  n=$((n + 1))
done
echo "built $n workspaces under $OUT"
