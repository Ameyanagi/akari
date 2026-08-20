# Roadmap

Each checkbox is intended to fit one reviewable issue. A milestone is complete
only when its implementation, focused tests, public example, and relevant
documentation land together.

## v0.1 — Foundation

### A0 — Numeric color contract

- [x] **A0.1 Normalized RGBA value:** validate finite components in `[0, 1]`,
  trust constructor-established invariants during reads, expose an explicit
  validation checkpoint, and test constructor boundaries plus direct-mutation
  validation.
- [x] **A0.2 Stored-space interpolation:** implement strict endpoint-bounded
  interpolation, including alpha, and test endpoints and a reference midpoint.
- [x] **A0.3 Numeric conversion policy:** fix strict range validation,
  deterministic binary64 threshold regions with equality toward the higher
  byte, adjacent-value fixtures, and transfer-function boundaries in
  `docs/numeric-conversion.md`; no constructor/exporter is added by this gate.

Completion gate: the root exports only `RGBA`; `pixi run check` and the installed
package smoke test exercise that public symbol.

### A1 — Explicit RGB-family spaces

- [x] **A1.1 sRGB value:** add a nominal sRGB type and define its transfer
  function independently of `RGBA` storage.
- [x] **A1.2 HSL conversion:** add bidirectional sRGB/HSL conversion with
  achromatic and hue-wrap reference fixtures.
- [x] **A1.3 HSV conversion:** add bidirectional sRGB/HSV conversion with the
  same boundary and round-trip coverage.
- [x] **A1.4 Conversion invariants:** property-test normalized ranges, primary
  colors, grayscale, and round trips over a deterministic sample grid.

Dependency gate: A1 begins after A0.3 fixes the numeric conversion policy. No
external color library or generated table is introduced.

### A2 — Palettes and interpolation

- [ ] **A2.1 Interpolation policy:** make stored-space, linear-light, and later
  perceptual interpolation distinguishable at the type or function boundary.
- [ ] **A2.2 Gradient sampling:** implement deterministic endpoint-inclusive
  sampling with explicit behavior for zero and one requested samples.
- [ ] **A2.3 Palette values:** define immutable categorical and sequential
  palette containers without renderer or plotting concepts.
- [ ] **A2.4 Palette validation:** reject empty required palettes and test stable
  ordering, indexing boundaries, and interpolation fixtures.

Dependency gate: palette APIs require A1's explicit color-space semantics.

### A3 — Scientific colormaps

- [ ] **A3.1 Data provenance:** select permissively licensed sources, record
  upstream versions/checksums, and define a deterministic generation command.
- [ ] **A3.2 Initial maps:** add viridis, plasma, inferno, and magma as sampled
  sequential colormaps with endpoint and checksum fixtures.
- [ ] **A3.3 Sampling contract:** test clamped versus rejected coordinates and
  document the chosen behavior before exporting convenience functions.

Dependency gate: generated tables land only after A2's palette and sampling
contracts are stable and the provenance review is complete.

### A4 — Release hardening

- [ ] **A4.1 Public API audit:** document every root export and remove any
  implementation type reachable from it.
- [ ] **A4.2 Downstream proof:** validate one pinned Sen integration and one
  pinned Kagerou integration without adding either as an Akari dependency.
- [ ] **A4.3 Package matrix:** build and smoke-test `.mojoc` packages on every
  declared CI platform and document numerical tolerances.

Release gate: all A0–A4 tasks pass unit, reference-value, and invariant tests;
downstream consumers depend on Akari, never the reverse.

## v0.2 — Usability

- Add ergonomic constructors only when v0.1 usage shows repeated friction.
- Expand palette composition and examples without adding plotting semantics.
- Submit the first modular-community recipe after Akari is useful on its own.

## v0.3 — Performance

- Add reproducible conversion and colormap-sampling benchmarks.
- Optimize measured bottlenecks behind unchanged numeric contracts.
- Consider SIMD only after scalar/reference parity is continuously tested.

## v1.0 — Stability

- Publish compatibility, deprecation, and numerical-accuracy policies.
- Support the declared OS/architecture CI matrix.
- Require real downstream use of the stabilized color-space contracts.

## Test matrix

- **Unit:** constructor boundaries, accessors, interpolation endpoints, palette
  indexing, and invalid configuration.
- **Reference value:** standard primary colors, RGB-family conversions, and
  published colormap samples with recorded provenance.
- **Invariant:** finite normalized outputs, deterministic sampling, monotone
  interpolation endpoints, and bounded conversion round trips.
- **Packaging:** root-import and primary-operation smoke tests against the
  installed `.mojoc`, not the source tree.

## Not planned

Rasterization, plotting, GUI widgets, terminal styling, image codecs, CSS color
parsing, ICC profiles, and full color-management systems are outside v0.1.
