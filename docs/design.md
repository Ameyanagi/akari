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

## Out of scope

Rasterization, plotting, GUI widgets, terminal styling, image codecs, and full color-management systems are outside v0.1.
