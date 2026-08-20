# Numeric conversion policy

This document fixes the numeric contract for future 8-bit component import and
export. It deliberately defines policy before adding an API. A0.3 is complete
when this contract is reviewable; no byte constructor or exporter is released by
this issue.

## Scope and color-space meaning

Byte conversion is quantization, not color-space conversion. It operates in the
declared stored space of a color type and never silently applies a transfer
function.

This policy uses IEEE 754 binary64 semantics. `RN64(r)` means the unique
binary64 value obtained by correctly rounding the exact real value `r` to
nearest, with ties to even. `CEIL64(r)` means the least binary64 value greater
than or equal to exact `r`; this is directed rounding toward positive infinity.
Hexadecimal values below are exact binary64 encodings, not decimal
approximations.

`RGBA` is currently transfer-function agnostic. A future raw byte API on this
type must say `stored` in its name and documentation; it must not imply sRGB.
The A1.1 sRGB type must define its encoded and linear-light relationship before
an API may use an `srgb8` name. Converting between encoded sRGB and linear light
is a separate operation from byte import/export.

Alpha uses the same numeric quantization rule but no color transfer function.
This policy does not choose straight versus premultiplied alpha.

## Import from 8-bit storage

For an unsigned byte `b` in `[0, 255]`, import as:

```text
normalized = RN64(b / 255)
```

An API accepting `UInt8` needs no clamping. Any future overload accepting a
wider integer must reject values outside `[0, 255]`; it must not clamp or wrap.

## Export to 8-bit storage

Before export, revalidate the complete semantic color value. NaN, either
infinity, and components outside `[0, 1]` raise an error, including invalid state
introduced through externally mutable Mojo 1.0 struct storage.

For each integer `n` in `[0, 254]`, define one normative binary64 threshold:

```text
T[n] = CEIL64((2*n + 1) / 510)
```

For a valid normalized binary64 component `x`, the exported byte is the number
of thresholds satisfying `x >= T[n]`. Equivalently, the intervals are:

```text
0                    when x < T[0]
b                    when T[b - 1] <= x < T[b], for b in [1, 254]
255                  when T[254] <= x
```

The directed threshold is the first representable input that is not below the
exact real half step. Equality therefore selects the higher byte, while its
immediate predecessor selects the lower byte. This is the complete observable
contract; an implementation may use a search or an integer estimate, but must
not substitute `floor(x * 255 + 0.5)`. That expression can round an immediately
lower binary64 input onto a half step before `floor` sees it. The valid domain
makes the threshold count an integer in `[0, 255]`; export does not silently
clamp. A future clamping operation, if justified, must be separately named and
must not replace the strict conversion.

## Acceptance fixtures

These fixtures are normative for the future implementation:

| Normalized input | Exported byte | Reason |
| ---: | ---: | --- |
| `0.0` | `0` | lower endpoint |
| `RN64(1 / 255)` | `1` | imported byte step |
| `T[127]` (`0.5`) | `128` | exact half step rounds upward |
| `T[126]` | `127` | interior half step rounds upward |
| `T[254]` | `255` | upper half step rounds upward |
| `1.0` | `255` | upper endpoint |

The following exact hexadecimal fixtures define adjacency behavior. `down` and
`up` are the immediately adjacent binary64 values around the named threshold;
the three exported results correspond to `down / T[n] / up`.

| `n` | `down` | `T[n]` | `up` | Exported bytes |
| ---: | --- | --- | --- | --- |
| `0` | `0x1.0101010101010p-9` | `0x1.0101010101011p-9` | `0x1.0101010101012p-9` | `0 / 1 / 1` |
| `126` | `0x1.fbfbfbfbfbfbfp-2` | `0x1.fbfbfbfbfbfc0p-2` | `0x1.fbfbfbfbfbfc1p-2` | `126 / 127 / 127` |
| `127` | `0x1.fffffffffffffp-2` | `0x1.0000000000000p-1` | `0x1.0000000000001p-1` | `127 / 128 / 128` |
| `131` | `0x1.0808080808080p-1` | `0x1.0808080808081p-1` | `0x1.0808080808082p-1` | `131 / 132 / 132` |
| `254` | `0x1.fefefefefefefp-1` | `0x1.fefefefefeff0p-1` | `0x1.fefefefefeff1p-1` | `254 / 255 / 255` |

The `n = 131` row is a required regression fixture: literal binary64 evaluation
of `floor(x * 255 + 0.5)` incorrectly exports its `down` value as `132`.

The implementation issue must add executable coverage for:

- all 256 byte values satisfying `export(import(b)) == b`;
- normalized samples satisfying
  `abs(x - RN64(export(x) / 255)) <= 1 / 510`;
- endpoints and, for every `n` in `[0, 254]`, `down / T[n] / up` exporting as
  `n / (n + 1) / (n + 1)`;
- rejection of NaN, positive/negative infinity, and out-of-range components;
- rejection after direct mutation of every reachable component; and
- identical numeric treatment of alpha without a color transfer function.

## Non-goals

This policy does not add constructors, exporters, sRGB transfer functions,
linear-light conversion, gamma configuration, HDR encodings, color profiles,
premultiplication, dithering, or broad color management.
