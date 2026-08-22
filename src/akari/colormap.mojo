"""Scientific colormaps backed by generated opaque RGBA byte tables."""

from std.builtin.comparable import Equatable
from std.collections import List
from std.io import Writable, Writer
from std.math import floor
from std.memory import bitcast
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
from .color import RGBA, _normalized_from_byte


def _clamp_colormap_coordinate(value: Float64) -> Float64:
    if value != value or value <= 0.0:
        return 0.0
    if value >= 1.0:
        return 1.0
    return value


def _interpolate_table(
    table: Array[SIMD[DType.uint8, 4], 256], coordinate: Float64
) -> RGBA:
    """Interpolate an already-clamped coordinate in one borrowed byte table."""
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


def _interpolate_table_bytes(
    table: Array[SIMD[DType.uint8, 4], 256], coordinate: Float64
) -> SIMD[DType.uint8, 4]:
    """Interpolate and quantize through the public scalar numeric path.

    Keeping one interpolation expression prevents target-specific contraction
    from moving an exact half-step to the opposite side of byte quantization.
    ``RGBA`` is a stack value, so this remains allocation-free.
    """
    return _interpolate_table(table, coordinate).stored_bytes()


def _normalization_width(lo: Float64, hi: Float64) raises -> Float64:
    if not isfinite(lo) or not isfinite(hi) or lo >= hi:
        raise Error(
            String(
                "bounds must be finite with lo < hi; got lo=",
                lo,
                ", hi=",
                hi,
            )
        )
    var width = hi - lo
    if not isfinite(width):
        raise Error(
            String(
                "normalization width must be finite; got hi - lo=",
                width,
                " for lo=",
                lo,
                ", hi=",
                hi,
                "; choose closer finite bounds",
            )
        )
    return width


def _validate_result_length(value_count: Int, result_count: Int) raises:
    if value_count != result_count:
        raise Error(
            String(
                "values and result buffers must have equal length; ",
                "got len(values)=",
                value_count,
                ", len(results)=",
                result_count,
                "; resize results to ",
                value_count,
            )
        )


def _has_exact_binary_reciprocal(width: Float64) -> Bool:
    """Return whether division by ``width`` is exact binary exponent scaling."""
    var bits = bitcast[DType.uint64](width)
    var exponent = (bits >> 52) & UInt64(0x7FF)
    var fraction = bits & UInt64(0x000F_FFFF_FFFF_FFFF)
    if exponent != UInt64(0):
        return fraction == UInt64(0)
    if fraction == UInt64(0) or (fraction & (fraction - UInt64(1))) != UInt64(0):
        return False
    return isfinite(1.0 / width)


def _map_into_table_scaled(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    inverse_width: Float64,
    results: Span[mut=True, RGBA, _],
    missing_color: Optional[RGBA],
):
    """Map through an exact binary reciprocal without changing division bits."""
    var missing = _interpolate_table(table, 0.0)
    if missing_color:
        missing = missing_color.value()

    for value_index in range(len(values)):
        var value = values[value_index]
        if value != value:
            results[value_index] = missing
            continue
        var coordinate = _clamp_colormap_coordinate((value - lo) * inverse_width)
        results[value_index] = _interpolate_table(table, coordinate)


def _map_into_table_divided(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    width: Float64,
    results: Span[mut=True, RGBA, _],
    missing_color: Optional[RGBA],
):
    """Map with the scalar reference normalization expression."""
    var missing = _interpolate_table(table, 0.0)
    if missing_color:
        missing = missing_color.value()

    for value_index in range(len(values)):
        var value = values[value_index]
        if value != value:
            results[value_index] = missing
            continue
        var coordinate = _clamp_colormap_coordinate((value - lo) / width)
        results[value_index] = _interpolate_table(table, coordinate)


def _map_bytes_into_table_scaled(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    inverse_width: Float64,
    results: Span[mut=True, SIMD[DType.uint8, 4], _],
    missing_color: Optional[RGBA],
):
    """Map bytes through an exact binary reciprocal."""
    var missing = table[0]
    if missing_color:
        missing = missing_color.value().stored_bytes()

    for value_index in range(len(values)):
        var value = values[value_index]
        if value != value:
            results[value_index] = missing
            continue
        var coordinate = _clamp_colormap_coordinate((value - lo) * inverse_width)
        results[value_index] = _interpolate_table_bytes(table, coordinate)


def _map_bytes_into_table_divided(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    width: Float64,
    results: Span[mut=True, SIMD[DType.uint8, 4], _],
    missing_color: Optional[RGBA],
):
    """Map bytes with the scalar reference normalization expression."""
    var missing = table[0]
    if missing_color:
        missing = missing_color.value().stored_bytes()

    for value_index in range(len(values)):
        var value = values[value_index]
        if value != value:
            results[value_index] = missing
            continue
        var coordinate = _clamp_colormap_coordinate((value - lo) / width)
        results[value_index] = _interpolate_table_bytes(table, coordinate)


def _map_into_normalized(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    width: Float64,
    results: Span[mut=True, RGBA, _],
    missing_color: Optional[RGBA],
):
    if _has_exact_binary_reciprocal(width):
        _map_into_table_scaled(table, values, lo, 1.0 / width, results, missing_color)
    else:
        _map_into_table_divided(table, values, lo, width, results, missing_color)


def _map_bytes_into_normalized(
    table: Array[SIMD[DType.uint8, 4], 256],
    values: Span[Float64, _],
    lo: Float64,
    width: Float64,
    results: Span[mut=True, SIMD[DType.uint8, 4], _],
    missing_color: Optional[RGBA],
):
    if _has_exact_binary_reciprocal(width):
        _map_bytes_into_table_scaled(
            table, values, lo, 1.0 / width, results, missing_color
        )
    else:
        _map_bytes_into_table_divided(table, values, lo, width, results, missing_color)


struct Colormap(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """An Int-backed handle to one immutable generated colormap table.

    Keeping only a nominal integer discriminant makes named colormaps
    compile-time materializable. Each batch operation selects and materializes
    its 1 KiB lookup table once, then reuses it for every interpolation.
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
        return _interpolate_table(table, coordinate)

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
            result.append(_interpolate_table(table, coordinate))
        return result^

    def map(
        self,
        values: Span[Float64, _],
        lo: Float64,
        hi: Float64,
        *,
        missing_color: Optional[RGBA] = None,
    ) raises -> List[RGBA]:
        """Map values through explicit finite bounds to colors.

        Raises ``bounds must be finite with lo < hi; got lo=<lo>, hi=<hi>``
        when either bound is non-finite or ``lo >= hi``, and rejects an infinite
        ``hi - lo`` normalization width. Each normalized value is clamped into
        ``[0, 1]`` and infinities reach the corresponding endpoint. A NaN uses
        ``missing_color``; omitting it preserves the historical low-endpoint
        color. Normalization exactly matches scalar division, including for tiny
        finite widths. Non-missing alpha is 1.0.
        """
        var width = _normalization_width(lo, hi)
        var result = List[RGBA](length=len(values), fill=RGBA.BLACK)
        var table = self._table()
        _map_into_normalized(
            table,
            values,
            lo,
            width,
            result,
            missing_color,
        )
        return result^

    def map_into(
        self,
        values: Span[Float64, _],
        lo: Float64,
        hi: Float64,
        results: Span[mut=True, RGBA, _],
        *,
        missing_color: Optional[RGBA] = None,
    ) raises:
        """Map ``values`` into caller-owned ``results`` without allocating.

        The buffers must have equal length. Bounds must be ordered and finite,
        and ``hi - lo`` must remain finite. Each normalized value is clamped;
        infinities reach endpoints. Normalization exactly matches scalar
        division, including for tiny finite widths. NaN writes ``missing_color``
        when supplied, otherwise the low endpoint for compatibility with
        ``map``. The colormap branch and table materialization occur once per
        call; ``results`` can be reused across calls. Contents are unspecified
        after an error.
        """
        var width = _normalization_width(lo, hi)
        _validate_result_length(len(values), len(results))
        var table = self._table()
        _map_into_normalized(
            table,
            values,
            lo,
            width,
            results,
            missing_color,
        )

    def map_bytes(
        self,
        values: Span[Float64, _],
        lo: Float64,
        hi: Float64,
        *,
        missing_color: Optional[RGBA] = None,
    ) raises -> List[SIMD[DType.uint8, 4]]:
        """Map values directly to strict stored-space RGBA bytes.

        Raises ``bounds must be finite with lo < hi; got lo=<lo>, hi=<hi>``
        when either bound is non-finite or ``lo >= hi``, and rejects an infinite
        normalization width. Each normalized value is clamped and infinities
        reach endpoints. NaN writes the strict stored bytes of ``missing_color``;
        omitting it preserves the historical low endpoint. Other alpha is 255,
        exactly matching ``map(...)[k].stored_bytes()``. Normalization exactly
        matches scalar division, including for tiny finite widths. Bytes carry
        straight, non-premultiplied alpha for raster consumers.
        """
        var width = _normalization_width(lo, hi)
        var result = List[SIMD[DType.uint8, 4]](
            length=len(values), fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
        )
        var table = self._table()
        _map_bytes_into_normalized(
            table,
            values,
            lo,
            width,
            result,
            missing_color,
        )
        return result^

    def map_bytes_into(
        self,
        values: Span[Float64, _],
        lo: Float64,
        hi: Float64,
        results: Span[mut=True, SIMD[DType.uint8, 4], _],
        *,
        missing_color: Optional[RGBA] = None,
    ) raises:
        """Map directly into caller-owned straight RGBA byte storage.

        The buffers must have equal length. Bounds must be ordered and finite,
        and ``hi - lo`` must remain finite. NaN writes ``missing_color`` in
        strict stored-space bytes, or the low endpoint when omitted. The selected
        table is materialized once and reused across the allocation-free kernel.
        Normalization exactly matches scalar division, including for tiny finite
        widths. ``results`` can be reused across calls; contents are unspecified
        after an error.
        """
        var width = _normalization_width(lo, hi)
        _validate_result_length(len(values), len(results))
        var table = self._table()
        _map_bytes_into_normalized(
            table,
            values,
            lo,
            width,
            results,
            missing_color,
        )

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Colormap(", self.name(), ")")
