from akari import Colormap
from std.collections import List
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


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
