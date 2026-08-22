from akari import Colormap, RGBA
from akari.colormap import _interpolate_table
from std.collections import List
from std.memory import bitcast
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


def _previous_positive_float64(value: Float64) -> Float64:
    return bitcast[DType.float64](bitcast[DType.uint64](value) - UInt64(1))


def _next_positive_float64(value: Float64) -> Float64:
    return bitcast[DType.float64](bitcast[DType.uint64](value) + UInt64(1))


def _assert_byte_fixture(
    colormap: Colormap,
    coordinate: Float64,
    red: Int,
    green: Int,
    blue: Int,
) raises:
    var expected = SIMD[DType.uint8, 4](
        UInt8(red), UInt8(green), UInt8(blue), UInt8(255)
    )
    assert_true(colormap.at(coordinate).stored_bytes() == expected)


def test_endpoint_and_exact_table_midpoint_fixtures() raises:
    var midpoint = 128.0 / 255.0
    _assert_byte_fixture(Colormap.VIRIDIS, 0.0, 68, 1, 84)
    _assert_byte_fixture(Colormap.VIRIDIS, midpoint, 33, 145, 140)
    _assert_byte_fixture(Colormap.VIRIDIS, 1.0, 253, 231, 37)

    _assert_byte_fixture(Colormap.PLASMA, 0.0, 13, 8, 135)
    _assert_byte_fixture(Colormap.PLASMA, midpoint, 204, 71, 120)
    _assert_byte_fixture(Colormap.PLASMA, 1.0, 240, 249, 33)

    _assert_byte_fixture(Colormap.INFERNO, 0.0, 0, 0, 4)
    _assert_byte_fixture(Colormap.INFERNO, midpoint, 188, 55, 84)
    _assert_byte_fixture(Colormap.INFERNO, 1.0, 252, 255, 164)

    _assert_byte_fixture(Colormap.MAGMA, 0.0, 0, 0, 4)
    _assert_byte_fixture(Colormap.MAGMA, midpoint, 183, 55, 121)
    _assert_byte_fixture(Colormap.MAGMA, 1.0, 252, 253, 191)

    _assert_byte_fixture(Colormap.TURBO, 0.0, 48, 18, 59)
    _assert_byte_fixture(Colormap.TURBO, midpoint, 164, 252, 60)
    _assert_byte_fixture(Colormap.TURBO, 1.0, 122, 4, 3)

    _assert_byte_fixture(Colormap.CIVIDIS, 0.0, 0, 34, 78)
    _assert_byte_fixture(Colormap.CIVIDIS, midpoint, 125, 124, 120)
    _assert_byte_fixture(Colormap.CIVIDIS, 1.0, 254, 232, 56)

    _assert_byte_fixture(Colormap.RED_BLUE, 0.0, 103, 0, 31)
    _assert_byte_fixture(Colormap.RED_BLUE, midpoint, 246, 247, 247)
    _assert_byte_fixture(Colormap.RED_BLUE, 1.0, 5, 48, 97)

    _assert_byte_fixture(Colormap.SPECTRAL, 0.0, 158, 1, 66)
    _assert_byte_fixture(Colormap.SPECTRAL, midpoint, 255, 255, 190)
    _assert_byte_fixture(Colormap.SPECTRAL, 1.0, 94, 79, 162)


def test_at_clamps_and_maps_nan_to_low_endpoint() raises:
    assert_true(Colormap.VIRIDIS.at(-0.5) == Colormap.VIRIDIS.at(0.0))
    assert_true(Colormap.VIRIDIS.at(1.5) == Colormap.VIRIDIS.at(1.0))
    assert_true(Colormap.VIRIDIS.at(Float64("nan")) == Colormap.VIRIDIS.at(0.0))


def test_at_is_piecewise_linear_between_table_entries() raises:
    var midpoint = Colormap.VIRIDIS.at(0.5 / 255.0)
    assert_true(_near(midpoint.red(), 68.0 / 255.0))
    assert_true(_near(midpoint.green(), 1.5 / 255.0))
    assert_true(_near(midpoint.blue(), 85.0 / 255.0))
    assert_true(midpoint.alpha() == 1.0)


def test_discrete_sample_contract() raises:
    assert_true(Colormap.PLASMA.sample(0, 1) == Colormap.PLASMA.at(0.0))
    assert_true(Colormap.PLASMA.sample(0, 5) == Colormap.PLASMA.at(0.0))
    assert_true(Colormap.PLASMA.sample(4, 5) == Colormap.PLASMA.at(1.0))

    with assert_raises(contains="sample count must be positive; got 0"):
        _ = Colormap.PLASMA.sample(0, 0)
    with assert_raises(contains="sample index must be within [0, 5); got 5"):
        _ = Colormap.PLASMA.sample(5, 5)


def test_colors_count_and_endpoint_contract() raises:
    var empty = Colormap.INFERNO.colors(0)
    var negative = Colormap.INFERNO.colors(-2)
    assert_true(len(empty) == 0)
    assert_true(len(negative) == 0)

    var singleton = Colormap.INFERNO.colors(1)
    assert_true(len(singleton) == 1)
    assert_true(singleton[0] == Colormap.INFERNO.at(0.0))

    var three = Colormap.INFERNO.colors(3)
    assert_true(len(three) == 3)
    assert_true(three[0] == Colormap.INFERNO.at(0.0))
    assert_true(three[1] == Colormap.INFERNO.at(0.5))
    assert_true(three[2] == Colormap.INFERNO.at(1.0))


def test_map_normalization_clamping_nan_and_bound_validation() raises:
    var values: List[Float64] = [0.0, 5.0, 10.0, Float64("nan"), 20.0]
    var mapped = Colormap.MAGMA.map(values, 0.0, 10.0)
    assert_true(len(mapped) == len(values))
    assert_true(mapped[0] == Colormap.MAGMA.at(0.0))
    assert_true(mapped[1] == Colormap.MAGMA.at(0.5))
    assert_true(mapped[2] == Colormap.MAGMA.at(1.0))
    assert_true(mapped[3] == Colormap.MAGMA.at(0.0))
    assert_true(mapped[4] == Colormap.MAGMA.at(1.0))

    with assert_raises(
        contains="bounds must be finite with lo < hi; got lo=1.0, hi=1.0"
    ):
        _ = Colormap.MAGMA.map(values, 1.0, 1.0)
    with assert_raises(
        contains="bounds must be finite with lo < hi; got lo=inf, hi=1.0"
    ):
        _ = Colormap.MAGMA.map(values, Float64("inf"), 1.0)
    with assert_raises(contains="normalization width must be finite"):
        _ = Colormap.MAGMA.map(values, -Float64.MAX_FINITE, Float64.MAX_FINITE)


def test_tiny_finite_width_uses_scalar_division_without_reciprocal_overflow() raises:
    var step = bitcast[DType.float64](UInt64(1))
    var lo = bitcast[DType.float64](UInt64(100))
    var hi = bitcast[DType.float64](UInt64(104))
    var values: List[Float64] = [
        lo,
        lo + step,
        lo + 2.0 * step,
        lo + 3.0 * step,
        hi,
    ]
    var mapped = Colormap.VIRIDIS.map(values, lo, hi)
    for index in range(len(values)):
        var coordinate = (values[index] - lo) / (hi - lo)
        assert_true(mapped[index] == Colormap.VIRIDIS.at(coordinate))

    var mapped_bytes = Colormap.VIRIDIS.map_bytes(values, lo, hi)
    for index in range(len(mapped)):
        assert_true(mapped_bytes[index] == mapped[index].stored_bytes())


def test_non_power_of_two_normalization_matches_scalar_division_exactly() raises:
    var values: List[Float64] = [0.1, 0.3, 0.7, 1.1, 3.0, 9.9]
    var colors = Colormap.PLASMA.map(values, 0.0, 10.0)
    var bytes = Colormap.PLASMA.map_bytes(values, 0.0, 10.0)
    for index in range(len(values)):
        var expected = Colormap.PLASMA.at(values[index] / 10.0)
        assert_true(colors[index] == expected)
        assert_true(bytes[index] == expected.stored_bytes())


def _assert_reciprocal_path_matches_scalar_oracle(
    colormap: Colormap,
    values: Span[Float64, _],
    lo: Float64,
    hi: Float64,
) raises:
    var colors = colormap.map(values, lo, hi)
    var bytes = colormap.map_bytes(values, lo, hi)
    for index in range(len(values)):
        var expected = colormap.at((values[index] - lo) / (hi - lo))
        assert_true(colors[index] == expected)
        assert_true(bytes[index] == expected.stored_bytes())


def test_nonunit_reciprocal_paths_with_nonzero_lo_match_scalar_oracle() raises:
    # Both widths are exact binary powers of two, so these cases enter the
    # reciprocal path without reducing it to the identity used by [0, 1].
    var wide: List[Float64] = [
        3.25,
        3.3,
        3.75,
        4.125,
        7.25,
        10.999999999999998,
        11.25,
    ]
    _assert_reciprocal_path_matches_scalar_oracle(Colormap.PLASMA, wide, 3.25, 11.25)

    var narrow: List[Float64] = [
        -7.75,
        -7.749,
        -7.7,
        -7.625,
        -7.500000000000001,
        -7.5,
    ]
    _assert_reciprocal_path_matches_scalar_oracle(
        Colormap.SPECTRAL, narrow, -7.75, -7.5
    )


def test_subnormal_width_and_subnormal_reciprocal_paths_match_division() raises:
    # 2^-1023 is the only subnormal power of two whose reciprocal remains
    # finite, so it must enter the multiplication path rather than the tiny-
    # width division fallback.
    var minimum_subnormal = bitcast[DType.float64](UInt64(1))
    var subnormal_width = bitcast[DType.float64](UInt64(0x0008_0000_0000_0000))
    var subnormal_values: List[Float64] = [
        -minimum_subnormal,
        0.0,
        bitcast[DType.float64](UInt64(0x0002_0000_0000_0000)),
        bitcast[DType.float64](UInt64(0x0004_0000_0000_0000)),
        bitcast[DType.float64](UInt64(0x0006_0000_0000_0000)),
        _previous_positive_float64(subnormal_width),
        subnormal_width,
        _next_positive_float64(subnormal_width),
    ]
    _assert_reciprocal_path_matches_scalar_oracle(
        Colormap.VIRIDIS, subnormal_values, 0.0, subnormal_width
    )

    # Conversely, 2^1023 has the exact subnormal reciprocal 2^-1023.
    var huge_width = bitcast[DType.float64](UInt64(0x7FE0_0000_0000_0000))
    var huge_values: List[Float64] = [
        0.0,
        huge_width * 0.25,
        huge_width * 0.5,
        huge_width * 0.75,
        _previous_positive_float64(huge_width),
        huge_width,
        _next_positive_float64(huge_width),
    ]
    _assert_reciprocal_path_matches_scalar_oracle(
        Colormap.SPECTRAL, huge_values, 0.0, huge_width
    )


def test_map_bytes_exactly_matches_map_stored_bytes() raises:
    var values: List[Float64] = [
        -2.0,
        0.25,
        4.5,
        Float64("nan"),
        Float64("-inf"),
        Float64("inf"),
    ]
    var mapped = Colormap.CIVIDIS.map(values, -1.0, 3.0)
    var mapped_bytes = Colormap.CIVIDIS.map_bytes(values, -1.0, 3.0)
    assert_true(len(mapped_bytes) == len(mapped))
    for index in range(len(mapped)):
        assert_true(mapped_bytes[index] == mapped[index].stored_bytes())
        assert_true(mapped_bytes[index][3] == UInt8(255))


def _assert_batch_matches_scalar(colormap: Colormap, count: Int) raises:
    var source: List[Float64] = [
        Float64("-inf"),
        -10.0,
        -2.0,
        -1.0,
        -0.999999999,
        -0.5,
        -1.0 / 255.0,
        0.0,
        0.5 / 255.0,
        1.0 / 255.0,
        0.25,
        0.5,
        0.75,
        254.5 / 255.0,
        1.0,
        1.000000001,
        3.0,
        Float64("inf"),
        Float64("nan"),
    ]
    var values = List[Float64](capacity=count)
    for index in range(count):
        values.append(source[index])

    var colors = List[RGBA](length=count, fill=RGBA.BLACK)
    var bytes = List[SIMD[DType.uint8, 4]](
        length=count, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    var lo = -1.3
    var hi = 2.8
    colormap.map_into(values, lo, hi, colors)
    colormap.map_bytes_into(values, lo, hi, bytes)

    for index in range(count):
        var expected = colormap.at((values[index] - lo) / (hi - lo))
        assert_true(colors[index] == expected)
        assert_true(bytes[index] == expected.stored_bytes())


def test_all_colormap_batch_kernels_match_scalar_with_tails_and_extremes() raises:
    var colormaps: List[Colormap] = [
        Colormap.VIRIDIS,
        Colormap.PLASMA,
        Colormap.INFERNO,
        Colormap.MAGMA,
        Colormap.TURBO,
        Colormap.CIVIDIS,
        Colormap.RED_BLUE,
        Colormap.SPECTRAL,
    ]
    var tail_counts: List[Int] = [0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 17, 19]
    for colormap in colormaps:
        for count in tail_counts:
            _assert_batch_matches_scalar(colormap, count)


def test_byte_kernel_matches_strict_scalar_quantization_dense_grid() raises:
    var colormaps: List[Colormap] = [
        Colormap.VIRIDIS,
        Colormap.PLASMA,
        Colormap.INFERNO,
        Colormap.MAGMA,
        Colormap.TURBO,
        Colormap.CIVIDIS,
        Colormap.RED_BLUE,
        Colormap.SPECTRAL,
    ]
    comptime count = 259
    var values = List[Float64](capacity=count)
    for index in range(count):
        values.append(Float64(index) / Float64(count - 1))
    var bytes = List[SIMD[DType.uint8, 4]](
        length=count, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    for colormap in colormaps:
        colormap.map_bytes_into(values, 0.0, 1.0, bytes)
        for index in range(count):
            assert_true(bytes[index] == colormap.at(values[index]).stored_bytes())


def test_byte_kernel_matches_scalar_at_every_table_half_step() raises:
    var colormaps: List[Colormap] = [
        Colormap.VIRIDIS,
        Colormap.PLASMA,
        Colormap.INFERNO,
        Colormap.MAGMA,
        Colormap.TURBO,
        Colormap.CIVIDIS,
        Colormap.RED_BLUE,
        Colormap.SPECTRAL,
    ]
    var values = List[Float64](capacity=255)
    for index in range(255):
        values.append((Float64(index) + 0.5) / 255.0)
    var bytes = List[SIMD[DType.uint8, 4]](
        length=len(values), fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    for colormap in colormaps:
        colormap.map_bytes_into(values, 0.0, 1.0, bytes)
        for index in range(len(values)):
            assert_true(bytes[index] == colormap.at(values[index]).stored_bytes())


def _first_scalar_transition_bits(
    table: Array[SIMD[DType.uint8, 4], 256],
    table_index: Int,
    channel: Int,
    boundary_byte: Int,
    increasing: Bool,
) -> UInt64:
    """Find the first public coordinate on the far side of one byte boundary."""
    var lower = bitcast[DType.uint64](Float64(table_index) / 255.0)
    var upper = bitcast[DType.uint64](Float64(table_index + 1) / 255.0)
    while lower < upper:
        var middle = lower + (upper - lower) // UInt64(2)
        var coordinate = bitcast[DType.float64](middle)
        var byte = Int(_interpolate_table(table, coordinate).stored_bytes()[channel])
        var reached_far_side = byte >= boundary_byte + 1
        if not increasing:
            reached_far_side = byte <= boundary_byte
        if reached_far_side:
            upper = middle
        else:
            lower = middle + UInt64(1)
    return lower


def test_byte_kernel_brackets_every_actual_scalar_transition_and_neighbors() raises:
    var colormaps: List[Colormap] = [
        Colormap.VIRIDIS,
        Colormap.PLASMA,
        Colormap.INFERNO,
        Colormap.MAGMA,
        Colormap.TURBO,
        Colormap.CIVIDIS,
        Colormap.RED_BLUE,
        Colormap.SPECTRAL,
    ]
    for colormap in colormaps:
        var table = colormap._table()
        var values = List[Float64](capacity=32768)
        var expected = List[SIMD[DType.uint8, 4]](capacity=32768)
        for table_index in range(255):
            var current = table[table_index]
            var following = table[table_index + 1]
            for channel in range(3):
                var current_byte = Int(current[channel])
                var following_byte = Int(following[channel])
                if current_byte == following_byte:
                    continue
                var lower_byte = current_byte
                var upper_byte = following_byte
                if lower_byte > upper_byte:
                    lower_byte = following_byte
                    upper_byte = current_byte
                for boundary_byte in range(lower_byte, upper_byte):
                    var transition_bits = _first_scalar_transition_bits(
                        table,
                        table_index,
                        channel,
                        boundary_byte,
                        following_byte > current_byte,
                    )
                    var predecessor = bitcast[DType.float64](
                        transition_bits - UInt64(1)
                    )
                    var transition = bitcast[DType.float64](transition_bits)
                    var successor = bitcast[DType.float64](transition_bits + UInt64(1))
                    var predecessor_byte = Int(
                        _interpolate_table(table, predecessor).stored_bytes()[channel]
                    )
                    var transition_byte = Int(
                        _interpolate_table(table, transition).stored_bytes()[channel]
                    )
                    if following_byte > current_byte:
                        assert_true(predecessor_byte == boundary_byte)
                        assert_true(transition_byte == boundary_byte + 1)
                    else:
                        assert_true(predecessor_byte == boundary_byte + 1)
                        assert_true(transition_byte == boundary_byte)

                    for coordinate in [predecessor, transition, successor]:
                        values.append(coordinate)
                        expected.append(
                            _interpolate_table(table, coordinate).stored_bytes()
                        )

        assert_true(len(values) > 0)
        var bytes = List[SIMD[DType.uint8, 4]](
            length=len(values), fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
        )
        colormap.map_bytes_into(values, 0.0, 1.0, bytes)
        for index in range(len(values)):
            if bytes[index] != expected[index]:
                raise Error(
                    String(
                        "byte kernel transition mismatch for ",
                        colormap.name(),
                        " at coordinate ",
                        values[index],
                        ": got ",
                        bytes[index][0],
                        ",",
                        bytes[index][1],
                        ",",
                        bytes[index][2],
                        "; expected ",
                        expected[index][0],
                        ",",
                        expected[index][1],
                        ",",
                        expected[index][2],
                    )
                )


def test_byte_kernel_bit_contract_on_large_deterministic_coordinates() raises:
    comptime count = 65539
    var values = List[Float64](capacity=count)
    for index in range(count):
        # A full-period modular walk exercises table cells and fractional bits
        # without random or clock state.
        values.append(Float64((index * 48271) % 1048583) / 1048582.0)
    var bytes = List[SIMD[DType.uint8, 4]](
        length=count, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    var colormaps: List[Colormap] = [
        Colormap.VIRIDIS,
        Colormap.PLASMA,
        Colormap.INFERNO,
        Colormap.MAGMA,
        Colormap.TURBO,
        Colormap.CIVIDIS,
        Colormap.RED_BLUE,
        Colormap.SPECTRAL,
    ]
    for colormap in colormaps:
        colormap.map_bytes_into(values, 0.0, 1.0, bytes)
        for index in range(count):
            assert_true(bytes[index] == colormap.at(values[index]).stored_bytes())


def test_into_reuses_outputs_and_supports_explicit_missing_color() raises:
    var first: List[Float64] = [Float64("nan"), -1.0, 1.0]
    var second: List[Float64] = [0.5, Float64("nan"), 0.0]
    var missing = RGBA(0.25, 0.5, 0.75, 0.125)
    var colors = List[RGBA](length=3, fill=RGBA.WHITE)
    var bytes = List[SIMD[DType.uint8, 4]](
        length=3, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )

    Colormap.TURBO.map_into(first, 0.0, 1.0, colors, missing_color=missing)
    assert_true(colors[0] == missing)
    assert_true(colors[1] == Colormap.TURBO.at(0.0))
    assert_true(colors[2] == Colormap.TURBO.at(1.0))

    Colormap.TURBO.map_into(second, 0.0, 1.0, colors, missing_color=missing)
    Colormap.TURBO.map_bytes_into(second, 0.0, 1.0, bytes, missing_color=missing)
    assert_true(colors[0] == Colormap.TURBO.at(0.5))
    assert_true(colors[1] == missing)
    assert_true(colors[2] == Colormap.TURBO.at(0.0))
    for index in range(len(colors)):
        assert_true(bytes[index] == colors[index].stored_bytes())


def test_into_rejects_output_length_mismatch() raises:
    var values: List[Float64] = [0.0, 1.0]
    var short_colors = List[RGBA](length=1, fill=RGBA.BLACK)
    var short_bytes = List[SIMD[DType.uint8, 4]](
        length=1, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    with assert_raises(contains="values and result buffers must have equal length"):
        Colormap.VIRIDIS.map_into(values, 0.0, 1.0, short_colors)
    with assert_raises(contains="values and result buffers must have equal length"):
        Colormap.VIRIDIS.map_bytes_into(values, 0.0, 1.0, short_bytes)


def test_names_equality_and_string_representation() raises:
    assert_true(Colormap.VIRIDIS != Colormap.PLASMA)
    assert_true(Colormap.VIRIDIS == Colormap.VIRIDIS)
    assert_true(Colormap.VIRIDIS.name() == "viridis")
    assert_true(Colormap.PLASMA.name() == "plasma")
    assert_true(Colormap.INFERNO.name() == "inferno")
    assert_true(Colormap.MAGMA.name() == "magma")
    assert_true(Colormap.TURBO.name() == "turbo")
    assert_true(Colormap.CIVIDIS.name() == "cividis")
    assert_true(Colormap.RED_BLUE.name() == "red_blue")
    assert_true(Colormap.SPECTRAL.name() == "spectral")
    assert_true(String(Colormap.TURBO) == "Colormap(turbo)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
