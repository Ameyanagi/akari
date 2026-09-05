# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Allocation-free `Gradient.map_into` and `Gradient.colors_into` sampling over
  caller-owned output spans, with exact scalar behavior in every `MixSpace`.
- A paired `bench-gradient` benchmark comparing allocating and reused sampling
  at 16 and 65,536 colors with complete scalar parity checks.

### Fixed

- Reconciled implemented A2/A3 roadmap gates with their tests and provenance,
  documented the current root exports, and tracked unfinished pinned downstream
  integration separately in issue #11.

## [0.1.1] - 2026-08-22

### Fixed

- Require exactly Mojo compiler 1.0.0 in emitted Conda package metadata and
  validate that runtime constraint after every package build.
- Document all channels required for a clean Pixi installation.

## [0.1.0] - 2026-08-22

### Added

- Initial experimental repository scaffold.
- Validated normalized `RGBA` values and component-wise interpolation.
- Exact equality, text formatting, explicit validation, and named RGBA colors.
- Strict binary64-threshold stored-byte import/export and lowercase hex output.
- Nominal gamma-encoded sRGB, linear-light sRGB, HSL, HSV, and Oklab values with
  explicit conversions and documented sRGB gamut clipping.
- Typed `MixSpace` choices for stored-space, linear-light, and Oklab mixing.
- Eight generated, checksum-pinned scientific colormaps with discrete sampling,
  batch mapping, and direct byte output.
- Category10 and Tableau10 palette factories with strict indexing and Euclidean
  cycling.
- Evenly spaced custom gradients with endpoint-exact interpolation, sampling,
  and alpha support.
- Nominal `PremultipliedRGBA` values and explicit conversion to and from
  straight-alpha `RGBA`, including a canonical transparent-black policy.

### Changed

- Trust constructor-validated color storage during read-only operations; callers
  can request an explicit validation checkpoint after unusual direct mutation.
- Use a measured inline scalar candidate quantizer with exact directed-threshold
  correction for direct batch colormap byte output.
- Preserve exact scalar-division normalization for finite colormap bounds,
  including tiny widths, and validate bounds before allocating batch outputs.

[Unreleased]: https://github.com/Ameyanagi/akari/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/Ameyanagi/akari/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/Ameyanagi/akari/releases/tag/v0.1.0
