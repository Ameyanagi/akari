# Gradient buffer reuse measurement

Command: `pixi run --locked bench-gradient`. CPU: Apple M4, arm64, macOS Darwin
25.5.0. Compiler: Mojo 1.0.0 (`ed45d567`), optimization level 3. The
[raw output](results/gradient-2026-09-05.txt) records the UTC time, source Git blob
IDs, platform metadata, checksums, and p50/p95 values. The run used the feature
worktree before commit; the recorded gradient and benchmark blob IDs identify
the measured sources, which are committed alongside this report.

The comparison runs the unchanged allocating `Gradient.colors(n)` implementation
and the new `colors_into(output)` in one compiled benchmark. The five input
stops and alpha values are defined in `bench_gradient.mojo`; 16-color palettes
and 65,536-color ramps each process 131,072 colors per measurement. There are
two warmups and eleven alternating-order measurement pairs. Full-buffer parity
with scalar `at()` and allocating `colors()` is checked before timing; paired
checksums must be identical. The output is created once outside the reused
variant's timing, while the convenience path allocates its result each pass.

| Mix space | Colors per pass | Allocating p50 ns/color | Reused p50 ns/color | Ratio allocating / reused |
| --- | ---: | ---: | ---: | ---: |
| stored | 16 | 41.19 | 18.75 | 2.20 |
| linear | 16 | 317.57 | 303.69 | 1.05 |
| oklab | 16 | 414.49 | 394.92 | 1.05 |
| stored | 65,536 | 13.56 | 12.63 | 1.07 |
| linear | 65,536 | 385.09 | 319.95 | 1.20 |
| oklab | 65,536 | 552.38 | 525.92 | 1.05 |

These are local observations under concurrent development load, not guaranteed
speedups. Tail timings, especially large OKLAB samples, show scheduling noise;
rerun on the target machine before choosing an application performance budget.
The reliable API improvement is removal of the per-pass result allocation,
with exact scalar output and caller-controlled buffer reuse. No SIMD or changed
color arithmetic is claimed.
