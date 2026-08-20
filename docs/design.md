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

Future byte import/export follows the strict rounding, range, mutation, and
color-space boundary in [the numeric conversion policy](numeric-conversion.md).
Quantization never implies a transfer function, and clamping is never hidden
inside a strict conversion.

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
