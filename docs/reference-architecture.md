# Reference architecture

This document records design research for Akari's post-A0 color-space, palette,
and scientific-colormap layers. It is an architecture input, not evidence that
the sketched API is implemented. The current public root remains `RGBA`.

The governing constraints are:

- Akari has no runtime dependency beyond the Mojo standard library.
- `RGBA` remains a normalized, transfer-function-agnostic stored value.
- Encoded and linear-light colors are different nominal types.
- Transfer functions, clamping, premultiplication, and interpolation spaces are
  never implied by an unqualified conversion or mix.
- Reference implementations inform behavior and layering; their source and data
  are not copied into Akari by this research branch.

## Reproducible reference snapshot

The following shallow clones were inspected locally. Commit IDs are the exact
research inputs rather than floating tags or branches.

| Reference | Commit | Declared license | Relevant API and data |
| --- | --- | --- | --- |
| [palette](https://github.com/Ogeon/palette) | `6ce2de444dc0a0b32feae55b1c6c8962c1b94bf8` | MIT OR Apache-2.0 | Rust color types, explicit encodings and conversions, alpha, mixing |
| [colorous](https://github.com/dtolnay/colorous) | `a3ca579fc1b1d05ee690562780f81549ff9fff7a` | Apache-2.0, with incorporated-data notices | Rust byte-color gradients and categorical schemes ported from d3-scale-chromatic |
| [Matplotlib](https://github.com/matplotlib/matplotlib) | `0c9b7e2afe620bf6ca6e3e1761d5cdb6065852aa` | Matplotlib license, with separate third-party notices | Normalized-float listed colormaps and scalar-to-RGBA lookup behavior |

The local clones live outside the Akari repository under
`/Users/ryuichi/dev/reference-libraries/akari/`. They are research material and
must not become package inputs by accident.

### Palette

Palette 0.7.7 names non-linear and linear sRGB separately as `Srgb<T>` and
`LinSrgb<T>`. Its RGB documentation explains why arithmetic on encoded values is
not linear-light arithmetic, and its encoding implementation exposes explicit
`into_linear` and `from_linear` operations. The implementation uses the standard
sRGB piecewise breakpoints `0.04045` and `0.0031308`; byte-to-linear conversions
may use generated lookup tables without changing the type-level distinction.

Its `Rgb<S, T>` separates the RGB standard from the component format, while
`into_format` changes only the numeric format. `Alpha<C, T>` wraps a color and
alpha, and `Srgba` and `LinSrgba` are aliases over the corresponding nominal
color. Palette provides clamping, fallible out-of-bounds conversion, and
unclamped conversion as visibly different APIs. `Mix` interpolates the type it
is called on and clamps the factor; its examples intentionally use `LinSrgb`.
Hue-bearing implementations use angular differences rather than interpolating a
raw scalar hue as if it were not cyclic. Premultiplied alpha is a separate
`PreAlpha` representation.

Two pinned-commit cautions reinforce Akari's validation rules. Palette's runtime
sRGB LUT builder is wired to `adobe_rgb_builder()` even though its static code
generator uses `srgb_lut_builder()`; therefore Akari will test any formula/LUT
pair against each other and against reference values. Also, `PreAlpha` says alpha
is clamped during conversion while `PreAlpha::new` forwards it directly to the
premultiplication implementation. Akari will make range validation executable
rather than relying on representation documentation.

Useful evidence in the pinned clone:

- `palette/src/rgb.rs`: encoded/linear rationale and `Srgb`/`LinSrgb` aliases;
- `palette/src/encoding/srgb.rs`: exact transfer branches and optimized formats;
- `palette/src/rgb/rgb.rs`: construction, numeric-format, and encoding APIs;
- `palette/src/alpha/alpha.rs`: generic straight-alpha wrapper;
- `palette/src/blend/pre_alpha.rs`: distinct premultiplied representation;
- `palette/src/convert/try_from_into_color.rs`: explicit out-of-bounds result;
- `palette/src/macros/mix.rs`: factor clamping and hue-aware interpolation.

The package manifest declares `MIT OR Apache-2.0`. At the inspected commit,
`LICENSE-MIT` has SHA-256
`be1313a4b07ab509c80083966cdd209a7d81d75cd57fcea24441fc9041ccf184`
and `LICENSE-APACHE` has SHA-256
`a60eea817514531668d7e00765731449fe14d059d3249e0bc93b36de45f759f2`.

### Colorous

Colorous 1.0.16 is a small, dependency-free-at-runtime Rust reference. Its
`Color` is three public `u8` components. `Gradient` offers
`eval_rational(i, n)` and `eval_continuous(t)`: continuous inputs are silently
clamped; the default rational implementation samples endpoints with
`i / (n - 1)` for `n > 1`; and `n == 0` panics. Sequential ColorBrewer schemes
have exact arrays for supported category counts and use spline sampling outside
those counts. Categorical schemes are fixed arrays. Viridis, inferno, magma,
and plasma are 256-entry byte ramps sampled through a component-wise spline.

Colorous describes its schemes as ported from d3-scale-chromatic and attributes
the four scientific maps to their Matplotlib designers. Its public `Color` type
does not nominally encode a transfer function or color space, so the byte tables
alone are not sufficient authority for Akari to label data as encoded sRGB.
That interpretation must be established from the selected original data source
and recorded explicitly.

Useful evidence in the pinned clone:

- `src/color.rs`: `u8` RGB value;
- `src/gradient.rs`: clamped continuous and endpoint-inclusive rational API;
- `src/interpolate.rs`: byte-component spline;
- `src/sequential.rs`: exact discrete ColorBrewer counts;
- `src/sequential_multi.rs`: 256-entry scientific ramps;
- `README.md`: d3 and scientific-map attribution;
- `NOTICE`: d3 BSD-3-Clause and ColorBrewer Apache-style notices.

The crate declares Apache-2.0. `LICENSE-APACHE` has SHA-256
`62c7a1e35f56406896d7aa7ca52d0cc0d272ac022b5d2796e7d6905db8a3636a`;
`NOTICE` has SHA-256
`f6ec602a0b522f0aaa05347ab437357c60e80bab99866012ae69889c01a19300`;
and the inspected table source has SHA-256
`9df84ea6c98ebfc809399043b2ea17648a9197e0f53f8fc58951cc6e947e2a8c`.

### Matplotlib

Matplotlib stores viridis, inferno, plasma, and magma as 256 normalized RGB
triples in `lib/matplotlib/_cm_listed.py` and constructs a `ListedColormap` for
each. A `Colormap` maps normalized float inputs to RGBA; the listed-colormap path
quantizes a float by multiplying by the table length, with exactly `1.0` mapped
back to the last entry. Values outside the range, NaN, and masked values use
separate under, over, and bad colors. Output can be normalized floats or bytes.
This is a feature-rich plotting contract, not a minimal color-library contract.

The colormap registry snapshots a registered map and returns copies on lookup.
This provides useful ownership precedent: later mutation of a caller's source
must not silently change a named palette. Matplotlib's generic RGB documentation
uses normalized channels, but the inspected table module does not itself declare
a transfer function. Akari must therefore record a verified color-space
interpretation when it selects the canonical upstream data.

Useful evidence in the pinned clone:

- `lib/matplotlib/_cm_listed.py`: normalized tables and named registrations;
- `lib/matplotlib/colors.py`: `Colormap` and `ListedColormap` lookup behavior;
- `lib/matplotlib/cm.py`: copy-on-register and copy-on-lookup registry;
- `doc/release/prev_whats_new/whats_new_1.5.rst`: introduction of the four maps;
- `doc/release/prev_whats_new/dflt_style_changes.rst`: design references;
- `LICENSE/LICENSE`: Matplotlib redistribution terms;
- `LICENSE/LICENSE_COLORBREWER`: separate ColorBrewer terms.

The main license requires retention of the Matplotlib license and copyright
notice in derivatives and a summary of changes. It has SHA-256
`5a1a81ea301728c8bba2933da832c0cd62229daf20893a024ab3d53244468dbc`.
`LICENSE_COLORBREWER` has SHA-256
`01173653fe745ce2124ec156d78b460582d2a719d2d9212804267e95fd2c97e7`.
The inspected listed-colormap source has SHA-256
`ddad3698f5129ceb1792a445371286c08bc9080298e657b3054aea19c9659ef9`.

## Target semantic model

### Stored values, encoded sRGB, and linear light

The layers must remain distinguishable:

```text
RGBA              normalized channels; transfer function unspecified
  ^ explicit stored-component construction/export only

Srgb / Srgba      sRGB primaries, D65 white point, sRGB-encoded components
  | explicit to_linear_srgb() / from_linear_srgb()
  v
LinearSrgb / LinearSrgba
                  same primaries and white point, linear-light components
```

`RGBA` is not made an alias for `Srgba`. Existing stored-space behavior remains
honest and stable. Code that means encoded sRGB must construct `Srgb` or `Srgba`;
code that means linear light must construct `LinearSrgb` or `LinearSrgba`.

The transfer operation is piecewise and explicit:

```text
encoded -> linear
  c / 12.92                         when c <= 0.04045
  ((c + 0.055) / 1.055) ** 2.4      otherwise

linear -> encoded
  12.92 * c                         when c <= 0.0031308
  1.055 * c ** (1 / 2.4) - 0.055   otherwise
```

This is not a configurable “gamma” operation. A future display space gets its
own type and specified transfer function. A type or method must not call stored
components “linear” merely because they use floating point.

### Normalized and byte formats

Numeric format conversion is orthogonal to transfer conversion. The existing
[numeric conversion policy](numeric-conversion.md) is authoritative:

- `RGBA.from_stored_u8(...)` and `to_stored_u8()` would quantize raw stored
  components and would not imply sRGB;
- `Srgb.from_u8(...)` and `to_u8()` would quantize encoded-sRGB components;
- `LinearSrgb` gets no `srgb8` shortcut because that name would combine a
  transfer and a format conversion;
- conversion rejects invalid normalized state and never silently clamps;
- an explicit `clamped()` operation, if later justified, remains separate.

The byte representation should be a nominal value or fixed component tuple, not
a widened signed integer API that can wrap. Export uses Akari's exact binary64
threshold contract, not a language-default cast. The acceptance condition
includes all 256 round trips and every adjacent half-step fixture.

### Alpha

The v0.1 default is straight alpha. Alpha is normalized coverage/opacity, does
not receive the color transfer function, and follows the same numeric byte
quantization only when exported.

`Srgba` and `LinearSrgba` remain distinct nominal values. Converting between
them transforms RGB and copies alpha exactly. A fully transparent value retains
its RGB channels; Akari does not invent a canonical transparent black.

Premultiplied alpha, if needed by Kagerou, is a separate type and explicit
operation. Premultiplication is defined on linear-light RGB. Akari will not
premultiply encoded sRGB components or hide encoded-to-linear conversion in a
constructor. Strict `try_unpremultiply` rejects alpha zero because the straight
RGB channels cannot be recovered. A separately named
`unpremultiply_or_transparent_black` convenience may later return transparent
black; it must not divide and return NaN.

Straight-alpha component interpolation and coverage-correct compositing are
different operations. Neither is called “blend” without a documented equation.

### Interpolation spaces

Interpolation is defined by the nominal input space:

- `RGBA.lerp_stored` (the current `RGBA.lerp` behavior) interpolates stored
  channels and alpha with no transfer assumption;
- `Srgb.lerp_encoded` interpolates encoded sRGB only when this visual behavior
  is deliberately requested;
- `LinearSrgb.lerp` performs linear-light component interpolation;
- later `Oklab.lerp` or `Oklch.lerp` performs perceptual-space interpolation;
- hue spaces require an explicit hue route, initially shortest arc, rather than
  ordinary scalar interpolation across the wrap.

The strict APIs reject non-finite amounts and amounts outside `[0, 1]`.
Separately named `sample_clamped` convenience may clamp finite coordinates after
A3.3 chooses that contract. There is no generic `lerp` on encoded `Srgb` that
silently converts through linear light.

Alpha interpolation is explicit and independent of the RGB transfer. A future
premultiplied interpolation path must accept the nominal premultiplied type.

### Palettes, gradients, and colormaps

These are three different abstractions:

```text
CategoricalPalette[C]
  ordered, finite colors; exact index lookup; never interpolated

Gradient[C]
  two or more ordered stops in one nominal color type; explicit interpolation

ScientificColormap
  named, provenance-bearing sampled map with a declared stored color space
```

A palette or gradient snapshots caller data on construction. It owns a validated
list and returns colors by value. This prevents later caller mutation from
changing the value. Because Mojo 1.0 exposes underscore-prefixed fields, every
public read or sample revalidates reachable list state until true private storage
is available.

Categorical palettes reject emptiness. Gradients reject fewer than two stops,
non-finite positions, positions outside `[0, 1]`, or non-increasing positions.
A scientific colormap must have at least two entries and declares whether its
table is encoded sRGB, linear-light sRGB, or another future nominal space.

Endpoint-inclusive regular sampling uses `i / (count - 1)` for `count > 1`.
The contract for requested sample counts is:

- zero returns an empty owned list without evaluating the map;
- one returns the lower endpoint;
- two or more include both endpoints exactly.

This differs deliberately from Colorous's one-sample upper-end behavior and
from Matplotlib's listed-map bin lookup. `at(t)` is strict; `at_clamped(t)` is a
separate possible A3.3 API. Categorical palettes do not expose either method.

## Ownership, errors, and mutation

Small color values use value semantics and are `Copyable` where their fields
permit it. Containers own snapshots rather than borrowing caller lists. Batch
operations may later accept Mojo-native spans for input and caller-provided
output, but no Akari-specific universal array is introduced.

Public constructors and semantic observations reject NaN, infinity, invalid
ranges, and invalid externally mutated storage. Errors name the operation and
invalid component or structural condition. The strict layer does not repair,
clamp, replace, or ignore bad values.

Policy choices with more than two states use a nominal total representation,
such as `InterpolationSpace`, whose every reachable state has defined behavior.
They are not represented by combinations of booleans that mutation can make
contradictory. Where current Mojo visibility prevents an airtight enum-like
value, construction and every observation validate a single discriminant.

## Generated data and license boundary

No reference source or color table is copied by this architecture work. A3.1 is
a hard gate before any scientific table lands.

A3.1 must choose the canonical upstream at an exact commit and record, per map:

```text
public map name
designers and original project attribution
source repository URL, commit, and file/range
declared color-space and transfer interpretation, with authority
source license and required notices
source-file SHA-256
deterministic generator version and command
generated-file SHA-256
entry count, numeric format, and quantization rule
any transformation and a concise change summary
```

Generated Mojo data is acceptable because users must not need Python, Rust, or C
at runtime. The generator may use a development-only toolchain, but it must be
pinned, deterministic, reviewable, and unable to fetch a moving network source.
It reads only a vendored, license-reviewed input or a verified local snapshot.

Akari's MIT OR Apache-2.0 source license does not erase an incorporated dataset's
license. Derivation from Colorous/d3 requires the applicable Apache-2.0,
BSD-3-Clause, and notice review. Derivation from Matplotlib requires retaining
its license and copyright notice and summarizing changes. ColorBrewer tables have
their separate terms. Any selected source must produce a distributable notice
file in source and binary packages. If the exact map data's license or color
space cannot be established, that map does not ship.

Do not reconstruct a table by reading numbers from several implementations to
avoid attribution. Either use a clearly licensed canonical source with its
obligations or independently generate a map from a published algorithm whose
inputs and licensing have been reviewed.

## Adopted and rejected reference ideas

### Adopted

- From Palette: encoded and linear-light types are nominally distinct; numeric
  format conversion is not transfer conversion; alpha and premultiplied alpha
  are separate representations; clamped, fallible, and unclamped behavior are
  distinct APIs.
- From Colorous: a tiny runtime surface, immutable named schemes, categorical
  data separate from continuous gradients, rational endpoint sampling, and no
  renderer or plotting dependency.
- From Matplotlib: normalize data outside the color primitive, snapshot owned
  maps at registration/construction, support explicit bad/under/over policy only
  at a higher mapping layer, and preserve scientific-map provenance.

### Rejected or deferred

- Palette's generic type-parameter matrix is too broad for Akari v0.1. Akari
  starts with a few nominal concrete types and grows only from tested demand.
- Implicit clamping of interpolation amounts, as used by Palette and Colorous,
  conflicts with Akari's strict public boundary. A separately named convenience
  can be added later.
- Colorous's untagged byte RGB cannot establish a transfer function, its
  component spline is not adopted as Akari's universal interpolation, and its
  `n == 0` panic / one-sample upper endpoint are rejected.
- Matplotlib's plotting concerns—normalization, masked arrays, bad/under/over
  colors, registries, mutable names, NumPy arrays, and byte-output switches—do
  not belong in Akari's foundation. Its listed colormap is discrete bin lookup,
  not Akari's gradient contract.
- Implicit gamma approximations, encoded-space arithmetic under an unqualified
  name, automatic gamut clipping, CSS parsing, ICC profiles, HDR encodings, and
  renderer-specific pixel formats remain outside v0.1.
- Runtime-configurable transfer/LUT builders are deferred. The pinned Palette
  wiring mismatch demonstrates why Akari's generated LUTs need reference parity,
  generator checksums, and a single nominal transfer owner.

## Minimal Mojo API sketch

This sketch is directional. Exact names land only with their issue, tests, and
package smoke coverage.

```mojo
from akari import RGBA, Srgb, Srgba, LinearSrgb, LinearSrgba

# Transfer-function-agnostic normalized storage.
var stored = RGBA(0.25, 0.5, 0.75, 1.0)

# Nominal encoded sRGB and an explicit transfer.
var encoded = Srgb(0.25, 0.5, 0.75)
var linear = encoded.to_linear_srgb()
var encoded_again = linear.to_srgb()

# Alpha is copied, not transfer-encoded.
var encoded_alpha = Srgba(0.25, 0.5, 0.75, 0.4)
var linear_alpha = encoded_alpha.to_linear_srgba()

# Quantization and transfer remain separate.
var encoded8 = encoded.to_u8()
var stored8 = stored.to_stored_u8()

# Each interpolation name exposes its space.
var light_mid = linear.lerp(LinearSrgb(1.0, 1.0, 1.0), 0.5)
var encoded_mid = encoded.lerp_encoded(Srgb(1.0, 1.0, 1.0), 0.5)
```

Non-root modules can expose containers without bloating `akari.__init__`:

```mojo
from akari.palette import CategoricalPalette
from akari.gradient import LinearSrgbGradient
from akari.colormap import viridis

var palette = CategoricalPalette(colors)
var first = palette.at(0)

var gradient = LinearSrgbGradient(stops)
var strict_color = gradient.at(0.25)

var map = viridis()
var samples = map.sample_regular(8)  # includes both endpoints
```

## Test architecture

Each issue adds unit, reference-value, and invariant coverage before optimization.

### Encodings and numeric formats

- exact sRGB piecewise breakpoints and immediate adjacent binary64 values;
- published primary, white, black, and gray transfer fixtures;
- encoded-to-linear-to-encoded and reverse round trips on a deterministic grid;
- all 256 encoded-byte round trips and all numeric-policy half-step neighbors;
- alpha bit-for-bit preservation across RGB transfer conversion;
- invalid constructor and post-construction mutation for every reachable field.

### Color-family conversions

- primary, secondary, grayscale, and achromatic HSL/HSV fixtures;
- hue wrap at zero/full-turn and shortest-arc interpolation across that boundary;
- deterministic normalized-grid round trips with documented tolerances;
- no NaN from degenerate chroma or fully transparent values.

### Interpolation and ownership

- exact endpoints and reference midpoints in stored, encoded, and linear light;
- a fixture proving encoded and linear-light midpoints intentionally differ;
- strict rejection of non-finite/out-of-range amounts;
- gradient positions, zero/one/many regular samples, and exact endpoint inclusion;
- caller-list mutation does not change an owned palette or gradient;
- direct mutation of every reachable container field is rejected on observation.

### Scientific data

- source and generated SHA-256 fixtures and expected table length;
- exact first, middle, and last entries plus a whole-table checksum;
- declared encoded/linear interpretation tested through nominal output type;
- regular sampling endpoints and strict/clamped coordinate behavior;
- deterministic regeneration produces no diff in a clean worktree;
- source and binary package smoke tests contain required notices.

## Benchmark architecture

Benchmarks publish methodology, not superiority claims. Each record includes
CPU, OS, Mojo version, compiler options, warmup, iterations, data size, and
whether allocation is included.

Initial benchmark cases are:

- scalar and batch encoded/linear conversion for 1, 256, and 1,000,000 colors;
- normalized/byte conversion over all byte values and a large deterministic grid;
- interpolation in stored, encoded, and linear-light spaces;
- categorical lookup and gradient sampling for 2, 16, 256, and 4096 outputs;
- scientific colormap exact-index and interpolated sampling;
- owned-container construction measured separately from repeated sampling.

SIMD may follow only after scalar/reference parity is continuously tested. Table
lookup, formula transfer, and branchless variants use the same public contract.

## Dependency and issue order

The target dependency direction is sparse:

```text
normalized storage and validation
              |
              v
nominal encoded / linear sRGB and explicit transfer
              |
              +----> HSL / HSV conversions
              |
              v
explicit interpolation policy
              |
              v
owned gradients and palettes
              |
              v
provenance-approved generated colormaps
```

The earliest dependency-ready, issue-sized order is:

1. **A0.4 Stored byte API:** implement only the already-specified strict raw
   `RGBA` byte import/export contract and exhaustive threshold tests.
2. **A1.1a Encoded sRGB value:** add nominal normalized `Srgb`/`Srgba`, with no
   transfer hidden in construction and a small root-export decision.
3. **A1.1b Linear sRGB transfer:** add `LinearSrgb`/`LinearSrgba` and exact
   explicit bidirectional transfer, including alpha preservation.
4. **A1.1c Encoded byte API:** apply the numeric-format contract to `Srgb` and
   `Srgba`; do not combine it with transfer conversion.
5. **A1.2 HSL** and then **A1.3 HSV:** define them relative to encoded sRGB and
   land achromatic/hue-wrap fixtures separately.
6. **A1.4 Conversion invariants:** deterministic property grids and mutation
   coverage gate all later color-space-aware containers.
7. **A2.1 Interpolation policy:** name stored, encoded, linear-light, and hue
   paths; defer perceptual interpolation until its nominal space exists.
8. **A2.2 Gradient sampling:** owned validated stops, strict coordinates, and
   zero/one/many endpoint-inclusive sampling.
9. **A2.3 Palette values:** categorical and sequential ownership without named
   scientific datasets; **A2.4** then closes validation and mutation gaps.
10. **A3.1 Data provenance:** select canonical sources, licenses, color-space
    interpretation, manifests, notices, and deterministic generator.
11. **A3.2 Initial maps:** add one reviewed generated map first, verify packaging,
    then add viridis/plasma/inferno/magma under the same gate.
12. **A3.3 Sampling contract:** stabilize strict versus explicitly clamped map
    sampling before root convenience exports.
13. **A4 release hardening:** public API audit, downstream proofs, package matrix,
    and reproducible performance baselines.

No item may pull in Sen, Kagerou, a window system, a plotting model, NumPy,
Python, Rust, C, a GPU backend, or runtime access to the cloned references.
