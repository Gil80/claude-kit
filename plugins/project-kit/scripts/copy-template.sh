#!/usr/bin/env bash
# Copies the project-kit template into a target folder.
# Never overwrites: existing files are reported as SKIPPED.
# Usage: copy-template.sh <target-dir> [--diff]
#   --diff  only report which template files are missing or differ; copy nothing.
set -eu

src="$(cd "$(dirname "$0")/../template" && pwd)"
target="${1:?usage: copy-template.sh <target-dir> [--diff]}"
mode="${2:-copy}"
mkdir -p "$target"
target="$(cd "$target" && pwd)"

created=0; skipped=0; differs=0
while IFS= read -r rel; do
  rel="${rel#./}"
  if [ -e "$target/$rel" ]; then
    if [ "$mode" = "--diff" ] && ! cmp -s "$src/$rel" "$target/$rel"; then
      echo "DIFFERS  $rel"; differs=$((differs + 1))
    elif [ "$mode" != "--diff" ]; then
      echo "SKIPPED  $rel (already exists)"
    fi
    skipped=$((skipped + 1))
  else
    if [ "$mode" = "--diff" ]; then
      echo "MISSING  $rel"
    else
      mkdir -p "$(dirname "$target/$rel")"
      cp -p "$src/$rel" "$target/$rel"
      echo "CREATED  $rel"
    fi
    created=$((created + 1))
  fi
done <<EOF
$(cd "$src" && find . -type f | LC_ALL=C sort)
EOF

chmod +x "$target/scripts/test.sh" "$target/.claude/hooks/"*.sh 2>/dev/null || true

if [ "$mode" = "--diff" ]; then
  echo "Summary: $created missing, $differs differ from the current template."
else
  echo "Summary: $created created, $skipped skipped."
fi
