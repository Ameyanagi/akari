#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  Darwin)
    benchmark_cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)
    ;;
  Linux)
    benchmark_cpu=$(uname -m)
    if command -v lscpu >/dev/null 2>&1; then
      benchmark_cpu=$(lscpu | awk -F: '/Model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}')
    fi
    ;;
  *)
    benchmark_cpu=$(uname -m)
    ;;
esac

printf '%s\n' 'metadata_schema=akari-gradient-benchmark-metadata-v1'
printf 'run_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'git_head=%s\n' "$(git rev-parse HEAD)"
printf 'benchmark_source_git_blob=%s\n' "$(git hash-object benchmarks/bench_gradient.mojo)"
printf 'gradient_source_git_blob=%s\n' "$(git hash-object src/akari/gradient.mojo)"
printf 'cpu=%s\n' "$benchmark_cpu"
printf 'os=%s\n' "$(uname -srv)"
printf 'architecture=%s\n' "$(uname -m)"
printf 'mojo=%s\n' "$(mojo --version)"
printf '%s\n' 'compiler_options=--optimization-level 3 -I src'
printf '%s\n' 'command=pixi run bench-gradient'

mojo run --optimization-level 3 -I src benchmarks/bench_gradient.mojo
