#!/usr/bin/env bash
set -euo pipefail

blocks_dir=.pixi/readme-blocks
bin_dir=.pixi/readme-bin

rm -rf "$blocks_dir" "$bin_dir"
mkdir -p "$blocks_dir" "$bin_dir"

block_count=$(
  awk -v blocks_dir="$blocks_dir" '
    BEGIN {
      in_fence = 0
      is_mojo = 0
      block_count = 0
    }

    !in_fence && /^```/ {
      in_fence = 1
      is_mojo = ($0 ~ /^```mojo[[:space:]]*$/)
      if (is_mojo) {
        block_count++
        file = blocks_dir "/block_" block_count ".mojo"
        printf "%s", "" > file
      }
      next
    }

    in_fence && /^```[[:space:]]*$/ {
      if (is_mojo) {
        close(file)
      }
      in_fence = 0
      is_mojo = 0
      next
    }

    in_fence && is_mojo {
      print > file
    }

    END {
      if (in_fence && is_mojo) {
        print "unterminated fenced mojo block in README.md" > "/dev/stderr"
        exit 1
      }
      print block_count
    }
  ' README.md
)

if [ "$block_count" -eq 0 ]; then
  echo "no fenced mojo blocks found in README.md" >&2
  exit 1
fi

block_number=1
while [ "$block_number" -le "$block_count" ]; do
  file="$blocks_dir/block_$block_number.mojo"
  if ! mojo build -I src "$file" -o "$bin_dir/block_$block_number"; then
    first_line=$(sed -n '1p' "$file")
    if [ -z "$first_line" ]; then
      first_line="<empty block>"
    fi
    echo "README Mojo block $block_number failed to compile: $first_line" >&2
    exit 1
  fi
  block_number=$((block_number + 1))
done
