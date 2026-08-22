#!/usr/bin/env bash

set -euo pipefail

rattler-build build \
  --recipe conda.recipe/recipe.yaml \
  -c conda-forge \
  -c https://conda.modular.com/max \
  -c https://repo.prefix.dev/modular-community

version="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' pixi.toml)"
mapfile_supported=false
if [[ -n "${BASH_VERSION:-}" && "${BASH_VERSINFO[0]}" -ge 4 ]]; then
  mapfile_supported=true
fi

if [[ "$mapfile_supported" == true ]]; then
  mapfile -t packages < <(find output -type f -name "mojo-akari-${version}-*.conda" -print)
else
  packages=()
  while IFS= read -r package; do
    packages+=("$package")
  done < <(find output -type f -name "mojo-akari-${version}-*.conda" -print)
fi

if [[ "${#packages[@]}" -ne 1 ]]; then
  echo "expected exactly one mojo-akari ${version} package, found ${#packages[@]}" >&2
  exit 1
fi

metadata="$(rattler-build package inspect "${packages[0]}" --json)"
compiler_specs="$(printf '%s\n' "$metadata" | grep -o '"mojo-compiler [^"]*"' || true)"
if [[ "$compiler_specs" != '"mojo-compiler ==1.0.0"' ]]; then
  echo "expected exact runtime dependency mojo-compiler ==1.0.0; found: ${compiler_specs:-none}" >&2
  exit 1
fi

printf 'validated %s with exact Mojo runtime dependency\n' "${packages[0]}"
