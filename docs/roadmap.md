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

Current public-surface gate: [the package root](../src/akari/__init__.mojo)
exports `RGBA`, `PremultipliedRGBA`, `Srgb`, `LinearSrgb`, `Hsl`, `Hsv`, `Oklab`,
`MixSpace`, `Gradient`, `Palette`, and `Colormap`. Internal tables and helpers
stay out of the root. `pixi run check` exercises their numeric and behavioral
contracts; the [installed-package smoke test](../conda.recipe/test_package.mojo)
checks representative RGBA, alpha, palette, gradient, and colormap operations.
The broader A4 release gates below remain separate from A0's implemented numeric
foundation.

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

- [x] **A2.1 Interpolation policy:** `MixSpace.STORED`, `LINEAR`, and `OKLAB`
  make interpolation explicit; [mix-space tests](../tests/test_mix_space.mojo)
  and [gradient tests](../tests/test_gradient.mojo) pin endpoints, alpha, and
  color-space semantics.
- [x] **A2.2 Gradient sampling:** deterministic endpoint-inclusive `sample`
  and `colors` behavior, including zero/one counts, is covered by
  [gradient tests](../tests/test_gradient.mojo). Caller-owned batch output is
  additionally covered by [batch tests](../tests/test_gradient_batch.mojo).
- [x] **A2.3 Palette values:** owned `Palette` values expose read-only public
  operations without renderer or plotting concepts; [palette tests](../tests/test_palette.mojo)
  cover construction, curated factories, and ordering. Sequential color lists
  come from `Gradient.colors` and `Colormap.colors`, covered by
  [gradient](../tests/test_gradient.mojo) and [colormap](../tests/test_colormap.mojo)
  tests. Underscore storage remains private by convention.
- [x] **A2.4 Palette validation:** constructor rejection, index boundaries,
  stable ordering, and cycling are covered by [palette tests](../tests/test_palette.mojo);
  [gradient tests](../tests/test_gradient.mojo) cover interpolation fixtures. Curated color sources are recorded
  in [data provenance](data-provenance.md#hand-curated-categorical-palettes).

Dependency gate: palette APIs require A1's explicit color-space semantics.

### A3 — Scientific colormaps

- [x] **A3.1 Data provenance:** the [generation ledger](data-provenance.md)
  records exact upstream versions, licenses, per-map/raw-data and generated-file
  SHA-256 values, and the deterministic
  [generation command](../scripts/generate_colormaps.py).
- [x] **A3.2 Initial maps:** viridis, plasma, inferno, and magma are implemented,
  alongside turbo, cividis, red-blue, and spectral. [Colormap tests](../tests/test_colormap.mojo)
  pin endpoint and midpoint fixtures; raw table and generated-file SHA-256
  values are recorded in [data provenance](data-provenance.md). Those checksums
  are provenance records, not an automated regeneration gate in the Mojo suite.
- [x] **A3.3 Sampling contract:** [colormap tests](../tests/test_colormap.mojo)
  cover clamping, NaN, count/index errors, normalized batch bounds, and scalar
  parity. [Design](design.md#batch-colormap-mapping) documents missing values and
  exact scalar normalization.

Dependency gate: generated tables land only after A2's palette and sampling
contracts are stable and the provenance review is complete.

### A4 — Release hardening

- [ ] **A4.1 Public API audit:** document every root export and remove any
  implementation type reachable from it.
- [ ] **A4.2 Downstream proof:** validate one pinned Sen integration and one
  pinned Kagerou integration without adding either as an Akari dependency.
  [Issue #11](https://github.com/Ameyanagi/akari/issues/11) specifies immutable
  versions, artifacts/numeric assertions, alpha/transfer boundaries, and the
  evidence needed to close this gate. Akari's own examples do not close it.
- [ ] **A4.3 Package matrix:** build and smoke-test `.mojoc` packages on every
  declared CI platform and document numerical tolerances.

Release gate: all A0–A4 tasks pass unit, reference-value, and invariant tests;
downstream consumers depend on Akari, never the reverse.

## v0.2 — Usability

- [x] Add nominal straight/premultiplied alpha conversion with a canonical
  zero-alpha policy and explicit stored-byte meaning.
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
