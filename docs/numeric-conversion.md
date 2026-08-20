# Numeric conversion policy

This document fixes the numeric contract for future 8-bit component import and
export. It deliberately defines policy before adding an API. A0.3 is complete
when this contract is reviewable; no byte constructor or exporter is released by
this issue.

## Scope and color-space meaning

Byte conversion is quantization, not color-space conversion. It operates in the
declared stored space of a color type and never silently applies a transfer
function.

`RGBA` is currently transfer-function agnostic. A future raw byte API on this
type must say `stored` in its name and documentation; it must not imply sRGB.
The A1.1 sRGB type must define its encoded and linear-light relationship before
an API may use an `srgb8` name. Converting between encoded sRGB and linear light
is a separate operation from byte import/export.

Alpha uses the same numeric quantization rule but no color transfer function.
This policy does not choose straight versus premultiplied alpha.

## Import from 8-bit storage

For an unsigned byte `b` in `[0, 255]`, import exactly as:

```text
normalized = Float64(b) / 255.0
```

An API accepting `UInt8` needs no clamping. Any future overload accepting a
wider integer must reject values outside `[0, 255]`; it must not clamp or wrap.

## Export to 8-bit storage

Before export, revalidate the complete semantic color value. NaN, either
infinity, and components outside `[0, 1]` raise an error, including invalid state
introduced through externally mutable Mojo 1.0 struct storage.

For a valid normalized component `x`:

```text
scaled = x * 255.0
byte = floor(scaled + 0.5)
```

This is round-to-nearest with exact half steps rounded toward the higher byte.
The valid domain makes the result an integer in `[0, 255]`; export does not
silently clamp. A future clamping operation, if justified, must be separately
named and must not replace the strict conversion.

## Acceptance fixtures

These fixtures are normative for the future implementation:

| Normalized input | Exported byte | Reason |
| ---: | ---: | --- |
| `0.0` | `0` | lower endpoint |
| `1.0 / 255.0` | `1` | exact imported step |
| `0.5` | `128` | exact half step rounds upward |
| `126.5 / 255.0` | `127` | interior half step rounds upward |
| `254.5 / 255.0` | `255` | upper half step rounds upward |
| `1.0` | `255` | upper endpoint |

The implementation issue must add executable coverage for:

- all 256 byte values satisfying `export(import(b)) == b`;
- normalized samples whose round-trip error is at most `0.5 / 255.0`;
- endpoints, exact half steps, and values immediately on either side;
- rejection of NaN, positive/negative infinity, and out-of-range components;
- rejection after direct mutation of every reachable component; and
- identical numeric treatment of alpha without a color transfer function.

## Non-goals

This policy does not add constructors, exporters, sRGB transfer functions,
linear-light conversion, gamma configuration, HDR encodings, color profiles,
premultiplication, dithering, or broad color management.
