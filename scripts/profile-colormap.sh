#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]] || [[ ! -x /usr/bin/sample ]]; then
  printf '%s\n' 'profile-colormap requires macOS /usr/bin/sample' >&2
  exit 2
fi

profile_mode=${AKARI_PROFILE_MODE:-bytes}
case "$profile_mode" in
  colors|bytes) ;;
  *)
    printf 'AKARI_PROFILE_MODE must be colors or bytes; got %s\n' "$profile_mode" >&2
    exit 2
    ;;
esac

profile_binary=.pixi/profile_colormap
profile_output=.pixi/akari-colormap-${profile_mode}.sample.txt
profile_disassembly=.pixi/akari-colormap-${profile_mode}.disassembly.txt
mojo build --optimization-level 3 --debug-level=line-tables -I src \
  benchmarks/profile_colormap.mojo -o "$profile_binary"
xcrun llvm-objdump --disassemble --demangle "$profile_binary" > "$profile_disassembly"

profile_pid=
cleanup_profile_child() {
  if [[ -n "$profile_pid" ]] && kill -0 "$profile_pid" 2>/dev/null; then
    kill "$profile_pid" 2>/dev/null || true
    wait "$profile_pid" 2>/dev/null || true
  fi
}
trap cleanup_profile_child EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

"$profile_binary" "$profile_mode" &
profile_pid=$!
sleep 0.25
/usr/bin/sample "$profile_pid" 5 -file "$profile_output"
wait "$profile_pid"
profile_pid=
printf 'profile=%s\n' "$profile_output"
printf 'disassembly=%s\n' "$profile_disassembly"
