"""Categorical color palettes with deterministic cycling."""

from std.builtin.comparable import Equatable
from std.collections import List
from std.io import Writable, Writer

from .color import RGBA, _Validated


struct Palette(Copyable, Equatable, Sized, Writable):
    """An owned, non-empty sequence of categorical colors.

    ``__getitem__`` uses strict zero-based indexing and never treats negative
    indices specially. ``cycle`` is the non-raising plotting path: it applies
    Euclidean modulo, so every integer wraps deterministically and ``cycle(-1)``
    returns the last color.

    Curated palettes are static factories rather than comptime constants because
    a ``List``-backed type cannot be ``ImplicitlyCopyable``; such constants are
    unusable at call sites in Mojo 1.0.
    """

    var _colors: List[RGBA]

    def __init__(out self, var colors: List[RGBA]) raises:
        if len(colors) == 0:
            raise Error("palette needs at least 1 color; got 0")
        self._colors = colors^

    def __init__(
        out self,
        var colors: List[RGBA],
        *,
        _validated: _Validated,
    ):
        self._colors = colors^

    @staticmethod
    def _from_validated(var colors: List[RGBA]) -> Self:
        """Take ownership of trusted non-empty palette data."""
        return Self(colors^, _validated=_Validated())

    def __len__(self) -> Int:
        return len(self._colors)

    def __getitem__(self, index: Int) raises -> RGBA:
        """Return a color by strict index, rejecting negative indices."""
        if index < 0 or index >= len(self._colors):
            raise Error(
                String(
                    "palette index must be within [0, ",
                    len(self._colors),
                    "); got ",
                    index,
                )
            )
        return self._colors[index]

    def cycle(self, index: Int) -> RGBA:
        """Wrap any integer by Euclidean modulo; ``-1`` selects the last color."""
        var wrapped = index % len(self._colors)
        if wrapped < 0:
            wrapped += len(self._colors)
        return self._colors[wrapped]

    @staticmethod
    def category10() -> Palette:
        """Return d3's ten-color Category10 palette."""
        var colors: List[RGBA] = [
            RGBA.from_stored_bytes(UInt8(0x1F), UInt8(0x77), UInt8(0xB4)),
            RGBA.from_stored_bytes(UInt8(0xFF), UInt8(0x7F), UInt8(0x0E)),
            RGBA.from_stored_bytes(UInt8(0x2C), UInt8(0xA0), UInt8(0x2C)),
            RGBA.from_stored_bytes(UInt8(0xD6), UInt8(0x27), UInt8(0x28)),
            RGBA.from_stored_bytes(UInt8(0x94), UInt8(0x67), UInt8(0xBD)),
            RGBA.from_stored_bytes(UInt8(0x8C), UInt8(0x56), UInt8(0x4B)),
            RGBA.from_stored_bytes(UInt8(0xE3), UInt8(0x77), UInt8(0xC2)),
            RGBA.from_stored_bytes(UInt8(0x7F), UInt8(0x7F), UInt8(0x7F)),
            RGBA.from_stored_bytes(UInt8(0xBC), UInt8(0xBD), UInt8(0x22)),
            RGBA.from_stored_bytes(UInt8(0x17), UInt8(0xBE), UInt8(0xCF)),
        ]
        return Self._from_validated(colors^)

    @staticmethod
    def tableau10() -> Palette:
        """Return d3's ten-color Tableau10 palette."""
        var colors: List[RGBA] = [
            RGBA.from_stored_bytes(UInt8(0x4E), UInt8(0x79), UInt8(0xA7)),
            RGBA.from_stored_bytes(UInt8(0xF2), UInt8(0x8E), UInt8(0x2C)),
            RGBA.from_stored_bytes(UInt8(0xE1), UInt8(0x57), UInt8(0x59)),
            RGBA.from_stored_bytes(UInt8(0x76), UInt8(0xB7), UInt8(0xB2)),
            RGBA.from_stored_bytes(UInt8(0x59), UInt8(0xA1), UInt8(0x4F)),
            RGBA.from_stored_bytes(UInt8(0xED), UInt8(0xC9), UInt8(0x48)),
            RGBA.from_stored_bytes(UInt8(0xB0), UInt8(0x7A), UInt8(0xA1)),
            RGBA.from_stored_bytes(UInt8(0xFF), UInt8(0x9D), UInt8(0xA7)),
            RGBA.from_stored_bytes(UInt8(0x9C), UInt8(0x75), UInt8(0x5F)),
            RGBA.from_stored_bytes(UInt8(0xBA), UInt8(0xB0), UInt8(0xAB)),
        ]
        return Self._from_validated(colors^)

    def __eq__(self, other: Self) -> Bool:
        if len(self._colors) != len(other._colors):
            return False
        for index in range(len(self._colors)):
            if self._colors[index] != other._colors[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Palette(", len(self._colors), " colors)")
