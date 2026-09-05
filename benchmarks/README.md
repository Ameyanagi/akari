# Colormap benchmarks

Run `pixi run bench-colormap` from the repository root. The wrapper records the
CPU, OS, architecture, exact Mojo version, compiler options, UTC time, and exact
command before running `bench_colormap.mojo`.

The deterministic fixture covers 1,024, 65,536, and 1,048,576 values. Interior
coordinates dominate, with regular NaN and positive/negative infinity samples
to retain missing-value and endpoint branches. Both allocation-free kernels use
caller-owned output buffers constructed before warmup. Each case maps at least
2,097,152 values per measurement, performs two warmup rounds, and reports p50
and p95 elapsed time across 31 measurements plus a deterministic checksum.
Before timing each size, the benchmark maps the full buffer through both public
kernels and asserts that every direct byte result equals the corresponding
scalar color result's strict `stored_bytes()` export. Independent tests cover all
255 directed quantization thresholds and bit-search every actual output-byte
transition in every generated table.

On macOS, `pixi run profile-colormap` builds the long-running workload at `-O3`
with line tables and samples its byte kernel for five seconds with
`/usr/bin/sample`. Set `AKARI_PROFILE_MODE=colors` to sample the floating-color
kernel. Reports are written under `.pixi/`, not committed. Attribute only the
main thread; Mojo runtime worker threads are initialized but idle in this scalar
workload. The workload wrappers are intentionally non-inline so optimized sample
reports retain a named `profile_colormap::_profile_bytes()` or
`profile_colormap::_profile_colors()` frame; production library kernels remain
fully inlineable.

Mojo may attribute an inlined library hotspot to the outer wrapper's source
line. The script therefore also writes a complete disassembly next to the sample
report. In the report, take an offset such as `_profile_bytes() + 4368`, find the
wrapper's entry address in the disassembly, add the offset in hexadecimal, and
inspect that address. This maps otherwise-collapsed samples back to the exact
normalization, interpolation, or quantization instruction sequence without
changing production inlining.

Results are development evidence, not permanent marketing claims. Keep benchmark
output with performance-sensitive review notes rather than committing machine-
specific numbers here.

## Gradient sampling

Run `pixi run bench-gradient` to compare the existing allocating `colors(n)`
with caller-owned `colors_into(output)`. Both sample the same five stops with
varying alpha in STORED, LINEAR, and OKLAB modes at 16 and 65,536 colors. Each
measurement covers 131,072 colors, with two warmups and eleven measurement
pairs whose execution order alternates. Output buffers are prepared before
timing; complete results are checked against scalar `at()` and allocating
`colors()` before each size, and per-pair checksums must match. Results report
p50/p95 nanoseconds per color. The wrapper records compiler, host, source hashes,
and command so measured code can be recovered even during a dirty checkout.

See [the recorded run](gradient-results.md) for local measurements and limits.
