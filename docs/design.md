# Design

## Principles

- Mojo is the runtime implementation language.
- Prefer pure Mojo and safe standard-library APIs.
- Keep the root API small, typed, documented, and testable.
- Separate semantic contracts from optimized CPU, SIMD, GPU, terminal, or
  rendering backends.
- Establish correctness and reference fixtures before optimization.
- Make invalid public configuration unrepresentable when practical; otherwise
  reject it explicitly.
- Preserve source mappings, numerical tolerances, ownership, and provenance as
  first-class data when the domain requires them.
- Do not add a framework-wide array, executor, renderer, or application model.

## Validation contract

Validated values establish their invariants at construction and are trusted
thereafter. Read-only accessors and operations do not revalidate stored state.
Each validated type exposes one explicit raising `validate()` checkpoint for
callers doing unusual low-level work; direct mutation of underscore-prefixed
fields is otherwise out of contract. Internal construction from compile-time or
invariant-preserving data uses a private non-raising unchecked path.

## Tradeoffs

The project accepts a narrower initial feature set in exchange for reviewable
contracts and sparse dependencies. Generated tables are acceptable when their
sources, Unicode or data version, licenses, checksums, and deterministic update
procedure are committed. Consumers must not need the generator toolchain.

## Numeric conversion

`RGBA.from_stored_bytes` and `RGBA.stored_bytes` implement the A0.3 strict
rounding, range, mutation, and color-space boundary in [the numeric conversion
policy](numeric-conversion.md). Quantization never implies a transfer function,
and clamping is never hidden inside a strict conversion.

## Batch gradient sampling

These batch APIs are unreleased and currently require the source-checkout
`pixi run --locked mojo run -I src your_file.mojo` path.

`Gradient.map_into(coordinates, results)` validates equal span lengths once,
then fills the caller's output using the exact scalar `at()` contract. A length
error occurs before any output write. `colors_into(results)` derives its sample
count from the output span, so it is non-raising: empty output is a no-op and a
single element receives the first stop. Neither method allocates or resizes
storage. `colors(n)` retains its allocating convenience contract.

The batch operations preserve the same segment division, exact stops, NaN and
infinity clamping, color-space transforms, and stored-space alpha interpolation
as scalar sampling. No reciprocal rewrite or alternative SIMD approximation is
introduced. Differential tests cover every short length, all interpolation
spaces, reusable subspans, endpoints, and invalid output sizes.

## Batch colormap mapping

`Colormap.map_into` and `Colormap.map_bytes_into` are the allocation-free batch
entry points. They require equal-length input and output spans, validate finite
ordered bounds and the derived normalization width once, select one generated
table once, and then reuse that table for the full kernel. The allocating `map`
and `map_bytes` conveniences validate bounds before allocating their output and
then share the same internal kernels.

The normative normalization expression is `(value - lo) / (hi - lo)`, including
for tiny finite widths. An exact reciprocal multiplication is selected only when
the width is a binary power of two and its reciprocal remains finite; in that
case it is bit-equivalent to division. All other widths use the scalar division
expression so batch results retain exact scalar semantics.

NaN is missing data rather than an endpoint coordinate. Batch callers can pass
an explicit `missing_color`; omitting it retains the original low-endpoint color
for source and behavioral compatibility. Positive and negative infinity remain
ordered extremes and clamp to the high and low endpoints respectively.

The Mojo 1.0 CPU kernel remains scalar because table interpolation needs
data-dependent gathers. Direct byte output uses a measured scalar candidate
quantizer: a cheap rounded-byte estimate followed by exact directed-threshold
correction at its adjacent boundary. The quantizer is forced inline because an
out-of-line call for each RGB component was a measured hotspot. Independent
`Int256` tests cover all 255 threshold neighbors, and table tests bit-search and
bracket every actual scalar output-byte transition before checking the direct
byte kernel. The benchmark asserts full-buffer equality between the public color
and byte kernels before every timed size.

## Alpha representation

`RGBA` is straight alpha. `PremultipliedRGBA` is a distinct nominal value whose
RGB components cannot exceed alpha. `RGBA.premultiplied()` multiplies stored
numeric RGB by alpha, while `PremultipliedRGBA.straight()` divides by nonzero
alpha. Zero alpha canonicalizes to transparent black because premultiplication
cannot preserve hidden straight RGB.

Neither conversion applies an RGB transfer function. A renderer that requires
linear-light premultiplication must convert RGB to a linear representation
before using this transfer-agnostic numeric operation.

## Nominal color spaces

Encoded sRGB, linear-light sRGB, HSL, and HSV are distinct nominal values. This
keeps transfer functions and cylindrical-space conversions explicit at method
boundaries, so a caller cannot accidentally substitute one space for another.
`RGBA` remains transfer-function agnostic and retains the project's alpha
semantics; the nominal RGB-family spaces have no alpha component.

HSL and HSV hues are expressed in degrees. Construction rejects non-finite hue
and circularly reduces every finite hue into `[0, 360)`. On RGB-to-cylindrical
conversion, achromatic colors use hue `0` and saturation `0`. In the reverse
direction, zero saturation ignores hue and produces the gray represented by
lightness or value.

The sRGB piecewise transfer functions use the standard IEC 61966-2-1 constants.
Because the pinned Mojo toolchain evaluates `Float64` powers with roughly `1e-9`
relative accuracy, the documented encode/decode round-trip tolerance is `1e-8`;
cylindrical (HSL/HSV) round trips are algebraic and hold `1e-12`.

## Out of scope

Rasterization, plotting, GUI widgets, terminal styling, image codecs, and full color-management systems are outside v0.1.
