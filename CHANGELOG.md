# Changelog

This project follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and uses semantic versioning after the first public release.

## [Unreleased]

### Added

- Initial experimental repository scaffold.
- Validated normalized `RGBA` values and component-wise interpolation.
- Exact equality, text formatting, explicit validation, and named RGBA colors.
- Strict binary64-threshold conversion policy for future transfer-explicit
  8-bit APIs.

### Changed

- Trust constructor-validated color storage during read-only operations; callers
  can request an explicit validation checkpoint after unusual direct mutation.
