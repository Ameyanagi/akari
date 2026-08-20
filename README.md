# Akari

> **Experimental — API may change before v1.0.**

Color science, palettes, and scientific colormaps for Mojo.

## Scope

Akari is a dependency-light color foundation whose values remain useful without plotting or rendering packages.

The first implementation milestone is intentionally narrow: implement predictable RGB, HSL, and HSV representations, conversions, interpolation, categorical palettes, and perceptually ordered scientific colormaps.
The project is independently installable and does not require any application
from the wider ecosystem.

## Development

Install [Pixi](https://pixi.sh/), then run:

```sh
pixi install --locked
pixi run check
pixi run example
```

The exact stable Mojo compiler and all development dependencies are captured in
`pixi.lock`. Runtime and library code is Mojo-first and pure Mojo wherever
practical. Build-time data generation may use another language when justified,
but generated outputs must be deterministic, checksum-pinned, licensed, and
documented.

## Package

The Mojo import is `akari`. The eventual Conda distribution is
`mojo-akari`. Source lives under `src/akari/`, whose
`__init__.mojo` defines the package boundary.

The first public slice provides constructor-validated normalized `RGBA` values
and explicit component-wise interpolation:

```mojo
from akari import RGBA

def main() raises:
    var middle = RGBA.black().lerp(RGBA(0.8, 0.9, 1.0), 0.5)
    print(middle.red(), middle.green(), middle.blue(), middle.alpha())
```

An `RGBA` value does not imply a transfer function. Interpolation operates in
the stored numeric space; future RGB and perceptual color-space types will make
other interpolation semantics explicit. Because Mojo 1.0 struct fields remain
externally mutable, accessors and semantic operations revalidate current storage
and raise instead of returning an invalid color.

## Repository map

- `src/akari/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
