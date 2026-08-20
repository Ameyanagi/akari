# /// script
# requires-python = ">=3.12"
# dependencies = ["matplotlib==3.10.5", "numpy==2.3.2"]
# ///
"""Generate akari's deterministic scientific colormap tables and ledger."""

from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np


MATPLOTLIB_VERSION = "3.10.5"
NUMPY_VERSION = "2.3.2"
BEGIN_MARKER = "<!-- BEGIN GENERATED COLORMAP LEDGER -->"
END_MARKER = "<!-- END GENERATED COLORMAP LEDGER -->"


@dataclass(frozen=True)
class ColormapSpec:
    upstream_name: str
    akari_name: str
    source_and_license: str


COLORMAPS = (
    ColormapSpec(
        "viridis",
        "VIRIDIS",
        "CC0; Stefan van der Walt & Nathaniel Smith (matplotlib)",
    ),
    ColormapSpec(
        "plasma",
        "PLASMA",
        "CC0; Stefan van der Walt & Nathaniel Smith (matplotlib)",
    ),
    ColormapSpec(
        "inferno",
        "INFERNO",
        "CC0; Stefan van der Walt & Nathaniel Smith (matplotlib)",
    ),
    ColormapSpec(
        "magma",
        "MAGMA",
        "CC0; Stefan van der Walt & Nathaniel Smith (matplotlib)",
    ),
    ColormapSpec(
        "turbo",
        "TURBO",
        "Apache-2.0; Anton Mikhailov, Google; via matplotlib's embedded table",
    ),
    ColormapSpec(
        "cividis",
        "CIVIDIS",
        "CC0; Nunez, Anderton & Renslow (PLOS ONE 2018); via matplotlib",
    ),
    ColormapSpec(
        "RdBu",
        "RED_BLUE",
        "Apache-2.0; ColorBrewer (Cynthia Brewer, Penn State); via matplotlib",
    ),
    ColormapSpec(
        "Spectral",
        "SPECTRAL",
        "Apache-2.0; ColorBrewer (Cynthia Brewer, Penn State); via matplotlib",
    ),
)


def sample_colormap(name: str) -> np.ndarray:
    """Return the reference map as 256 opaque RGBA byte rows."""
    rgb = np.rint(
        plt.get_cmap(name)(np.linspace(0.0, 1.0, 256))[:, :3] * 255.0
    ).astype(np.uint8)
    alpha = np.full((256, 1), 255, dtype=np.uint8)
    return np.concatenate((rgb, alpha), axis=1)


def render_mojo(tables: tuple[tuple[ColormapSpec, np.ndarray], ...]) -> bytes:
    """Render the mblack-stable Mojo source as UTF-8 bytes."""
    lines = [
        '"""Generated colormap tables; see ``docs/data-provenance.md``."""',
        "",
        "# Generated file; do not edit.",
        "# Regenerate with: uv run scripts/generate_colormaps.py",
        f"# Source: matplotlib {MATPLOTLIB_VERSION}",
        "",
    ]
    for table_index, (spec, rgba) in enumerate(tables):
        lines.append(
            f"comptime _{spec.akari_name}_TABLE: "
            "Array[SIMD[DType.uint8, 4], 256] = ["
        )
        for red, green, blue, alpha in rgba:
            lines.append(
                "    SIMD[DType.uint8, 4]"
                f"({red}, {green}, {blue}, {alpha}),"
            )
        lines.append("]")
        if table_index != len(tables) - 1:
            lines.append("")
    return ("\n".join(lines) + "\n").encode()


def hex_rgb(row: np.ndarray) -> str:
    """Format an RGBA row as its RGB swatch value."""
    return f"#{row[0]:02x}{row[1]:02x}{row[2]:02x}"


def render_ledger(
    tables: tuple[tuple[ColormapSpec, np.ndarray], ...], mojo_sha256: str
) -> str:
    """Render the generated section of the provenance document."""
    lines = [
        BEGIN_MARKER,
        "",
        "## Generated colormap ledger",
        "",
        "| Akari constant | Upstream name | Upstream project | Original source "
        "and license | First | Last | Raw RGBA SHA-256 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for spec, rgba in tables:
        raw_digest = sha256(rgba.tobytes(order="C")).hexdigest()
        lines.append(
            f"| `_{spec.akari_name}_TABLE` | `{spec.upstream_name}` | "
            f"[matplotlib {MATPLOTLIB_VERSION}]"
            "(https://github.com/matplotlib/matplotlib/tree/v3.10.5) | "
            f"{spec.source_and_license} | "
            f"`{hex_rgb(rgba[0])}` | `{hex_rgb(rgba[-1])}` | `{raw_digest}` |"
        )
    lines.extend(
        [
            "",
            "Generated table file SHA-256: "
            f"`{mojo_sha256}` (`src/akari/_colormap_tables.mojo`).",
            "",
            "Exact regeneration command: "
            "`uv run scripts/generate_colormaps.py`.",
            "",
            END_MARKER,
        ]
    )
    return "\n".join(lines)


def update_ledger(document: str, ledger: str) -> str:
    """Replace only the marked generated ledger and retain surrounding prose."""
    if document.count(BEGIN_MARKER) != 1 or document.count(END_MARKER) != 1:
        raise RuntimeError(
            "data provenance document must contain exactly one generated ledger "
            "marker pair"
        )
    before, marked_and_after = document.split(BEGIN_MARKER, maxsplit=1)
    _, after = marked_and_after.split(END_MARKER, maxsplit=1)
    return before + ledger + after


def main() -> None:
    if matplotlib.__version__ != MATPLOTLIB_VERSION:
        raise RuntimeError(
            f"expected matplotlib {MATPLOTLIB_VERSION}; got {matplotlib.__version__}"
        )
    if np.__version__ != NUMPY_VERSION:
        raise RuntimeError(f"expected numpy {NUMPY_VERSION}; got {np.__version__}")

    repository = Path(__file__).resolve().parent.parent
    mojo_path = repository / "src" / "akari" / "_colormap_tables.mojo"
    provenance_path = repository / "docs" / "data-provenance.md"
    tables = tuple((spec, sample_colormap(spec.upstream_name)) for spec in COLORMAPS)

    mojo_source = render_mojo(tables)
    mojo_path.write_bytes(mojo_source)
    ledger = render_ledger(tables, sha256(mojo_source).hexdigest())
    provenance = provenance_path.read_text(encoding="utf-8")
    provenance_path.write_bytes(update_ledger(provenance, ledger).encode("utf-8"))


if __name__ == "__main__":
    main()
