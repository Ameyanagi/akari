# Akari

> **Experimental — API may change before v1.0.**

Color science, palettes, and scientific colormaps for Mojo.

## Scope

Akari is a dependency-light color foundation whose values remain useful without
plotting or rendering packages.

The initial implementation is intentionally focused: predictable RGB, HSL,
HSV, and Oklab representations; explicit interpolation; categorical palettes;
custom gradients; and perceptually ordered scientific colormaps.
The project is independently installable and does not require any application
from the wider ecosystem.

## Install

For a Pixi project, add the ecosystem channel and install Akari:

```sh
pixi project channel add https://ameyanagi.github.io/mojo-channel
pixi add mojo-akari
```

The package is named `mojo-akari`; its Mojo import is `akari`.

As a source-checkout alternative, clone this repository and install its locked
environment:

```sh
git clone https://github.com/Ameyanagi/akari.git
cd akari
pixi install --locked
```

Then run your own file against the library from the checkout root:

```sh
pixi run mojo run -I src your_file.mojo
```

The `-I src` flag puts the `akari` package on the import path. The same flag
works from another directory with the full path:
`mojo run -I path/to/akari/src your_file.mojo`.

## Quickstart

The public slice covers continuous data colors, categorical series colors, and
custom ramps with deterministic hex output:

```mojo
from akari import Colormap, Gradient, Palette, RGBA
from std.collections import List

def main() raises:
    var value_color = Colormap.VIRIDIS.at(0.72)
    var series_color = Palette.tableau10().cycle(11)
    var stops: List[RGBA] = [RGBA.WHITE, RGBA(0.14, 0.42, 0.81)]
    var brand = Gradient(stops^)
    print(value_color.hex())
    print(series_color.hex())
    print(brand.at(0.5).hex())
```

For the interpolation choice, see the `MixSpace` docstring: `STORED` for data
fidelity, `LINEAR` for physical light, and `OKLAB` for looks. Curated palettes
are factories because Mojo 1.0 cannot make their `List`-backed values
`ImplicitlyCopyable` for usable comptime constants.

## Example: coloring anomalies with a diverging map

Map anomaly values in `[-3, 3]` onto `RED_BLUE`, then produce RGB bytes for a
renderer while keeping the full `RGBA` values alongside:

```mojo
from akari import Colormap
from std.collections import List


def main() raises:
    var anomalies: List[Float64] = [-3.0, -1.5, -0.25, 0.0, 0.75, 2.0, 3.0]
    var colors = Colormap.RED_BLUE.map(anomalies, -3.0, 3.0)
    var stored = Colormap.RED_BLUE.map_bytes(anomalies, -3.0, 3.0)
    for index in range(len(anomalies)):
        print(
            anomalies[index],
            "-> rgb(",
            stored[index][0],
            ",",
            stored[index][1],
            ",",
            stored[index][2],
            ") alpha=",
            colors[index].alpha(),
        )
```

The `examples/` directory holds this program and the `basic`, `series_cycle`,
and `colorbar` examples.

## Transfer functions and validation

An `RGBA` value does not imply a transfer function. Because Mojo 1.0 struct
fields remain externally mutable, direct mutation of underscore-prefixed
storage is out of contract. Construction validates components, accessors then
trust stored state, and `validate()` provides an explicit checkpoint after
unusual low-level work. Byte and hex import/export follows the
[numeric conversion policy](docs/numeric-conversion.md): quantization is strict,
never silently clamps, and never adds an implied transfer function.

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

## Repository map

- `src/akari/`: library or application source
- `tests/`: TestSuite unit, reference-value, and invariant tests
- `examples/`: small compilable usage programs
- `benchmarks/`: reproducible methodology and later benchmark programs
- `docs/`: architecture, design, compatibility, roadmap, and release policy
- `conda.recipe/`: local Rattler build recipe

Source lives under `src/akari/`, whose `__init__.mojo` defines the package
boundary.

See [the architecture](docs/architecture.md), [design principles](docs/design.md),
and [roadmap](docs/roadmap.md) before proposing a new dependency or feature.

## License

Licensed under either Apache-2.0 or MIT, at your option.
