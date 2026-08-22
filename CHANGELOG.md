# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

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
