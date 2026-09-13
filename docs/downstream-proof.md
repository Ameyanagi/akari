# Pinned downstream proof (A4.2)

This development-only integration fixture exercises Akari's public color APIs
through actual Sen SVG rendering and Kagerou path rasterization. The adapters
live in `tests/downstream/`; neither consumer is an Akari runtime or package
dependency. No sibling checkout, floating branch, installed consumer package,
or manually edited lockfile is used.

## Reproduce

With Git, Python 3.9+ (standard library only), and Pixi 0.76.2 available, run
from the Akari checkout:

```console
pixi install --locked
pixi run --locked check-downstream
pixi run --locked check
```

The [runner](../scripts/check-downstream.py) checks the compiler identity and
fetches fresh, detached repositories at the full commits in
[pins.json](../tests/downstream/pins.json):

| Component | Immutable version/revision |
| --- | --- |
| Mojo | `1.0.0 (ed45d567)` from `pixi.lock` |
| Akari baseline | `28e58cbdb3d22bf4d919d5402fcea77b69f112a9` |
| Sen | `8494b4f98f4d359f25129a2b3af6899062e71717` |
| Kagerou | `81a394882a3b01dda46eb3a4c329b4665dce8b13` |

Each fixture is compiled with `mojo build --Werror`, with only the selected
Akari source root and that consumer's source root on the explicit import path.
Both consumers are tested twice: first against the immutable Akari baseline,
then against the current checkout. The latter detects regressions in future
Akari changes without making the historical baseline float. The report records
the checkout commit, dirty status, Akari source digest, exact build commands,
fixture/runner hashes, compiler identity, platform, observations, and artifact
hashes. A failed run exits nonzero and removes any previous success report.

Results are written to `.pixi/downstream-proof/`:

- `baseline/` and `checkout/`: `sen.svg`, `sen.log`, and `kagerou.log`.
- `report.json`: provenance and verified observations for all four executions.

The [CI workflow](../.github/workflows/ci.yml) runs the same command on Linux
x86-64, Linux ARM64, and macOS ARM64. Successful jobs publish
`downstream-proof-<runner>` artifacts containing the report, SVGs, and logs.
The normal `check` task remains independent of network access to consumers;
CI runs `check-downstream` as a separate job in this workflow.

## Sen: palette and scientific colormap consumption

[sen_palette.mojo](../tests/downstream/sen_palette.mojo) creates four three-point
lines through `sen.Plot`. It reads Category10 and viridis from Akari, explicitly
interprets the stored RGB as encoded sRGB, and passes `Srgb.hex()` to
`SeriesStyle`. Straight alpha travels separately through `with_opacity`.
It does not premultiply or decode RGB before SVG output.

The Mojo fixture first asserts the Akari values. The runner then parses the
rendered SVG as XML and asserts four actual series polylines, their ordering,
three points per series, their colors, and their opacity. Matching text in a
title or legend is insufficient to pass.

| Series | Akari source | Expected SVG stroke | Expected opacity |
| --- | --- | --- | --- |
| 0 | `Palette.category10()[0]` | `#1f77b4` | `1` |
| 1 | `Colormap.VIRIDIS.at(0)` | `#440154` | `1` |
| 2 | `Colormap.VIRIDIS.at(128/255)` | `#21918c` | `1` |
| 3 | `Colormap.VIRIDIS.at(1)`, alpha set to 0.5 | `#fde725` | `0.5` |

Colors, alpha, series count, and point counts are exact assertions. The middle
sample selects table entry 128 explicitly; it is not the interpolated `0.5`
coordinate. SVG hashes are recorded for provenance, not imposed as a
cross-platform floating-point layout contract.

## Kagerou: alpha, transfer, and raster boundaries

[kagerou_alpha.mojo](../tests/downstream/kagerou_alpha.mojo) starts with Akari
straight `RGBA(0.5, 0.25, 0.75, 0.5)`. Its straight stored bytes are
`(128, 64, 191, 128)`; the fixture verifies that passing these directly to
Kagerou's premultiplied `Rgba8` raises because blue exceeds alpha.

The adapter accepts nominal `PremultipliedRGBA`, quantizes once using
`stored_bytes()`, then constructs `Rgba8`. Two explicit policies are exercised:

1. Premultiply the stored RGB directly. No transfer function runs implicitly.
2. Interpret RGB as encoded sRGB, decode with `Srgb.to_linear()`, preserve
   straight alpha, then premultiply the linear components before quantization.

For the second policy, reference linear RGB is
`(0.21404114048223255, 0.05087608817155679, 0.5225215539683921)`.
The absolute tolerance is `1e-9`, accommodating the pinned Mojo compiler's
optimized power operation (the observed macOS error is below `2e-10`). Byte
quantization and all pixel comparisons remain exact.

Both policies rasterize a rectangle with corners `(1, 1)` and `(5, 3)` into a
6-by-4 Kagerou surface. All eight interior pixels and sixteen untouched exterior
pixels are checked on transparent black. Source-over compositing onto opaque
white is checked separately, along with untouched background pixels:

| Policy | Expected pixel on transparent black | Expected pixel over white |
| --- | --- | --- |
| Stored RGB, premultiplied | `(64, 32, 96, 128)` | `(191, 159, 223, 255)` |
| Decoded linear RGB, premultiplied | `(27, 6, 67, 128)` | `(154, 133, 194, 255)` |

Kagerou composites the supplied numeric bytes; it does not decode or encode
sRGB. The linear surface above remains linear and would require an explicit
encoding step before display. The fixture also asserts straight/premultiplied
round-trip values and canonical zero-alpha black, and checks that compositing
the transparent color leaves an existing pixel unchanged.

## Observed evidence

The commands above were run on macOS 26.5.1 ARM64 on 2026-09-14 (JST), using the
pinned compiler and revisions. Both baseline and current-checkout executions produced
the four expected Sen series and all expected Kagerou pixels shown above.
The complete Akari validation suite passed (89 tests in 10 suites, formatting,
README compilation, example builds, and package precompilation). Both generated
SVGs had SHA-256
`3d0d263bf870ce692a193a9a3919b1d7bbb484eca8638d8c47b71bbf6964a7ae`.
Mutating a rendered series color, dropping its alpha, or removing a data point
was separately confirmed to fail the SVG verifier. Per-commit CI reports
provide the corresponding Linux and macOS results and retain the generated SVGs.

When updating a consumer pin, change its full SHA in `pins.json`, rerun both
commands, and review the numeric/SVG observations before updating this ledger.
Changing the Akari baseline is a deliberate new historical proof; it does not
replace testing the current checkout.
