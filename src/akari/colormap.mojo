"""Scientific colormaps backed by generated opaque RGBA byte tables."""

from std.builtin.comparable import Equatable
from std.collections import List
from std.io import Writable, Writer
from std.math import floor
from std.utils.numerics import isfinite

from ._colormap_tables import (
    _CIVIDIS_TABLE,
    _INFERNO_TABLE,
    _MAGMA_TABLE,
    _PLASMA_TABLE,
    _RED_BLUE_TABLE,
    _SPECTRAL_TABLE,
    _TURBO_TABLE,
    _VIRIDIS_TABLE,
)
from .color import RGBA, _byte_from_normalized, _normalized_from_byte


def _clamp_colormap_coordinate(value: Float64) -> Float64:
    if value != value or value <= 0.0:
        return 0.0
    if value >= 1.0:
        return 1.0
    return value


def _validate_bounds(lo: Float64, hi: Float64) raises:
    if not isfinite(lo) or not isfinite(hi) or lo >= hi:
        raise Error(
            String(
                "bounds must be finite with lo < hi; got lo=",
                lo,
                ", hi=",
                hi,
            )
        )


struct Colormap(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """An Int-backed handle to one immutable generated colormap table.

    Keeping only a nominal integer discriminant makes named colormaps
    compile-time materializable. A lookup copies its selected 1 KiB table once,
    then performs every requested interpolation against that local table.
    """

    var _value: Int

    comptime VIRIDIS = Colormap(_value=0)
    comptime PLASMA = Colormap(_value=1)
    comptime INFERNO = Colormap(_value=2)
    comptime MAGMA = Colormap(_value=3)
    comptime TURBO = Colormap(_value=4)
    comptime CIVIDIS = Colormap(_value=5)
    comptime RED_BLUE = Colormap(_value=6)
    comptime SPECTRAL = Colormap(_value=7)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def name(self) -> String:
        """Return the stable lowercase name used by legends and colorbars."""
        if self._value == 0:
            return "viridis"
        if self._value == 1:
            return "plasma"
        if self._value == 2:
            return "inferno"
        if self._value == 3:
            return "magma"
        if self._value == 4:
            return "turbo"
        if self._value == 5:
            return "cividis"
        if self._value == 6:
            return "red_blue"
        return "spectral"

    def _table(self) -> Array[SIMD[DType.uint8, 4], 256]:
        if self._value == 0:
            return materialize[_VIRIDIS_TABLE]()
        if self._value == 1:
            return materialize[_PLASMA_TABLE]()
        if self._value == 2:
            return materialize[_INFERNO_TABLE]()
        if self._value == 3:
            return materialize[_MAGMA_TABLE]()
        if self._value == 4:
            return materialize[_TURBO_TABLE]()
        if self._value == 5:
            return materialize[_CIVIDIS_TABLE]()
        if self._value == 6:
            return materialize[_RED_BLUE_TABLE]()
        return materialize[_SPECTRAL_TABLE]()

    def at(self, t: Float64) -> RGBA:
        """Linearly sample the byte table with opaque alpha.

        ``t`` is clamped into ``[0, 1]``; NaN deterministically samples 0.0.
        Interpolation occurs in normalized stored component space. The returned
        alpha is exactly 1.0.
        """
        var table = self._table()
        var coordinate = _clamp_colormap_coordinate(t)
        var position = coordinate * 255.0
        var index = Int(floor(position))
        var fraction = position - Float64(index)
        var current = table[index]
        if index == 255 or fraction == 0.0:
            return RGBA._from_validated(
                _normalized_from_byte(current[0]),
                _normalized_from_byte(current[1]),
                _normalized_from_byte(current[2]),
                1.0,
            )

        var following = table[index + 1]
        var remaining = 1.0 - fraction
        return RGBA._from_validated(
            _normalized_from_byte(current[0]) * remaining
            + _normalized_from_byte(following[0]) * fraction,
            _normalized_from_byte(current[1]) * remaining
            + _normalized_from_byte(following[1]) * fraction,
            _normalized_from_byte(current[2]) * remaining
            + _normalized_from_byte(following[2]) * fraction,
            1.0,
        )

    def sample(self, i: Int, n: Int) raises -> RGBA:
        """Return endpoint-inclusive discrete sample ``i`` of ``n``.

        Raises ``sample count must be positive; got <n>`` when ``n <= 0`` and
        ``sample index must be within [0, <n>); got <i>`` outside the index
        range. ``n == 1`` samples 0.0. Derived coordinates lie in ``[0, 1]``;
        lookup uses the same clamp policy as ``at``, including NaN mapping to
        0.0, and returns alpha 1.0.
        """
        if n <= 0:
            raise Error(String("sample count must be positive; got ", n))
        if i < 0 or i >= n:
            raise Error(
                String(
                    "sample index must be within [0, ",
                    n,
                    "); got ",
                    i,
                )
            )
        if n == 1:
            return self.at(0.0)
        return self.at(Float64(i) / Float64(n - 1))

    def colors(self, n: Int) -> List[RGBA]:
        """Return ``n`` evenly spaced, endpoint-inclusive opaque colors.

        Zero and negative counts return an empty list; a count of one samples
        0.0. Coordinates are clamped into ``[0, 1]`` and NaN would sample 0.0,
        matching ``at``. Generated coordinates are finite, and alpha is 1.0.
        """
        if n <= 0:
            return List[RGBA]()

        var result = List[RGBA](capacity=n)
        var table = self._table()
        for sample_index in range(n):
            var coordinate = 0.0
            if n > 1:
                coordinate = Float64(sample_index) / Float64(n - 1)
            coordinate = _clamp_colormap_coordinate(coordinate)
            var position = coordinate * 255.0
            var table_index = Int(floor(position))
            var fraction = position - Float64(table_index)
            var current = table[table_index]
            if table_index == 255 or fraction == 0.0:
                result.append(
                    RGBA._from_validated(
                        _normalized_from_byte(current[0]),
                        _normalized_from_byte(current[1]),
                        _normalized_from_byte(current[2]),
                        1.0,
                    )
                )
                continue

            var following = table[table_index + 1]
            var remaining = 1.0 - fraction
            result.append(
                RGBA._from_validated(
                    _normalized_from_byte(current[0]) * remaining
                    + _normalized_from_byte(following[0]) * fraction,
                    _normalized_from_byte(current[1]) * remaining
                    + _normalized_from_byte(following[1]) * fraction,
                    _normalized_from_byte(current[2]) * remaining
                    + _normalized_from_byte(following[2]) * fraction,
                    1.0,
                )
            )
        return result^

    def map(
        self, values: Span[Float64, _], lo: Float64, hi: Float64
    ) raises -> List[RGBA]:
        """Map values through explicit finite bounds to opaque colors.

        Raises ``bounds must be finite with lo < hi; got lo=<lo>, hi=<hi>``
        when either bound is non-finite or ``lo >= hi``. Each normalized value
        is clamped into ``[0, 1]``; NaN deterministically maps to 0.0, and
        infinities clamp to their corresponding endpoint. Alpha is 1.0.
        """
        _validate_bounds(lo, hi)
        var result = List[RGBA](capacity=len(values))
        var table = self._table()
        var width = hi - lo
        for value_index in range(len(values)):
            var coordinate = 0.0
            if values[value_index] == values[value_index]:
                coordinate = (values[value_index] - lo) / width
            coordinate = _clamp_colormap_coordinate(coordinate)
            var position = coordinate * 255.0
            var table_index = Int(floor(position))
            var fraction = position - Float64(table_index)
            var current = table[table_index]
            if table_index == 255 or fraction == 0.0:
                result.append(
                    RGBA._from_validated(
                        _normalized_from_byte(current[0]),
                        _normalized_from_byte(current[1]),
                        _normalized_from_byte(current[2]),
                        1.0,
                    )
                )
                continue

            var following = table[table_index + 1]
            var remaining = 1.0 - fraction
            result.append(
                RGBA._from_validated(
                    _normalized_from_byte(current[0]) * remaining
                    + _normalized_from_byte(following[0]) * fraction,
                    _normalized_from_byte(current[1]) * remaining
                    + _normalized_from_byte(following[1]) * fraction,
                    _normalized_from_byte(current[2]) * remaining
                    + _normalized_from_byte(following[2]) * fraction,
                    1.0,
                )
            )
        return result^

    def map_bytes(
        self, values: Span[Float64, _], lo: Float64, hi: Float64
    ) raises -> List[SIMD[DType.uint8, 4]]:
        """Map values directly to strict stored-space opaque RGBA bytes.

        Raises ``bounds must be finite with lo < hi; got lo=<lo>, hi=<hi>``
        when either bound is non-finite or ``lo >= hi``. Each normalized value
        is clamped into ``[0, 1]``; NaN deterministically maps to 0.0, and
        infinities clamp to their corresponding endpoint. RGB uses akari's
        strict normalized-byte quantization and alpha is 255, exactly matching
        ``map(...)[k].stored_bytes()``. The bytes carry straight,
        non-premultiplied alpha for raster consumers.
        """
        _validate_bounds(lo, hi)
        var result = List[SIMD[DType.uint8, 4]](capacity=len(values))
        var table = self._table()
        var width = hi - lo
        for value_index in range(len(values)):
            var coordinate = 0.0
            if values[value_index] == values[value_index]:
                coordinate = (values[value_index] - lo) / width
            coordinate = _clamp_colormap_coordinate(coordinate)
            var position = coordinate * 255.0
            var table_index = Int(floor(position))
            var fraction = position - Float64(table_index)
            var current = table[table_index]
            if table_index == 255 or fraction == 0.0:
                result.append(current)
                continue

            var following = table[table_index + 1]
            var remaining = 1.0 - fraction
            result.append(
                SIMD[DType.uint8, 4](
                    _byte_from_normalized(
                        _normalized_from_byte(current[0]) * remaining
                        + _normalized_from_byte(following[0]) * fraction
                    ),
                    _byte_from_normalized(
                        _normalized_from_byte(current[1]) * remaining
                        + _normalized_from_byte(following[1]) * fraction
                    ),
                    _byte_from_normalized(
                        _normalized_from_byte(current[2]) * remaining
                        + _normalized_from_byte(following[2]) * fraction
                    ),
                    255,
                )
            )
        return result^

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Colormap(", self.name(), ")")
