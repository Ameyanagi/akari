from akari import Gradient, MixSpace, RGBA
from std.collections import List
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


def _black_to_white(space: MixSpace) raises -> Gradient:
    var stops: List[RGBA] = [RGBA.BLACK, RGBA.WHITE]
    return Gradient(stops^, space)


def _assert_exact_endpoints(space: MixSpace) raises:
    var first = RGBA.from_stored_bytes(
        UInt8(0x13), UInt8(0x57), UInt8(0x9B), UInt8(0x24)
    )
    var last = RGBA.from_stored_bytes(
        UInt8(0xE2), UInt8(0x46), UInt8(0x8A), UInt8(0xBD)
    )
    var stops: List[RGBA] = [first, last]
    var gradient = Gradient(stops^, space)
    assert_true(gradient.at(0.0) == first)
    assert_true(gradient.at(1.0) == last)


def test_constructor_requires_two_stops() raises:
    var empty = List[RGBA]()
    with assert_raises(contains="gradient needs at least 2 stops; got 0"):
        _ = Gradient(empty^)

    var singleton: List[RGBA] = [RGBA.BLACK]
    with assert_raises(contains="gradient needs at least 2 stops; got 1"):
        _ = Gradient(singleton^)

    var pair: List[RGBA] = [RGBA.BLACK, RGBA.WHITE]
    var gradient = Gradient(pair^)
    assert_true(gradient.space() == MixSpace.OKLAB)


def test_endpoints_are_bit_exact_in_every_space() raises:
    _assert_exact_endpoints(MixSpace.STORED)
    _assert_exact_endpoints(MixSpace.LINEAR)
    _assert_exact_endpoints(MixSpace.OKLAB)


def test_stored_midpoint_is_componentwise() raises:
    var gradient = _black_to_white(MixSpace.STORED)
    assert_true(gradient.at(0.5) == RGBA(0.5, 0.5, 0.5))


def test_oklab_midpoint_is_perceptual_gray() raises:
    var midpoint = _black_to_white(MixSpace.OKLAB).at(0.5)
    assert_true(_near(midpoint.red(), 0.3885, 1e-3))
    assert_true(_near(midpoint.green(), midpoint.red(), 1e-7))
    assert_true(_near(midpoint.blue(), midpoint.red(), 1e-7))
    assert_true(midpoint.alpha() == 1.0)


def test_oklab_gradient_matches_rgba_mix() raises:
    var first = RGBA(0.15, 0.3, 0.75, 0.2)
    var second = RGBA(0.85, 0.6, 0.1, 0.8)
    var stops: List[RGBA] = [first, second]
    var gradient = Gradient(stops^, MixSpace.OKLAB)
    assert_true(gradient.at(0.25) == first.mix(second, 0.25, MixSpace.OKLAB))


def test_linear_midpoint_is_encoded_linear_half() raises:
    var midpoint = _black_to_white(MixSpace.LINEAR).at(0.5)
    assert_true(_near(midpoint.red(), 0.7354, 1e-3))
    assert_true(midpoint.red() == midpoint.green())
    assert_true(midpoint.red() == midpoint.blue())
    assert_true(midpoint.alpha() == 1.0)


def test_at_clamps_and_maps_nan_to_first_stop() raises:
    var gradient = _black_to_white(MixSpace.OKLAB)
    assert_true(gradient.at(-1.0) == gradient.at(0.0))
    assert_true(gradient.at(2.0) == gradient.at(1.0))
    assert_true(gradient.at(Float64("nan")) == gradient.at(0.0))


def test_multiple_stops_select_exact_knots_and_local_segments() raises:
    var stops: List[RGBA] = [RGBA.BLACK, RGBA.RED, RGBA.WHITE]
    var gradient = Gradient(stops^, MixSpace.STORED)
    assert_true(gradient.at(0.5) == RGBA.RED)
    assert_true(gradient.at(0.25) == RGBA(0.5, 0.0, 0.0))


def test_determinism_and_space_sensitive_equality() raises:
    var first = _black_to_white(MixSpace.OKLAB)
    var second = _black_to_white(MixSpace.OKLAB)
    var linear = _black_to_white(MixSpace.LINEAR)
    assert_true(first == second)
    assert_true(first != linear)

    for index in range(11):
        var coordinate = Float64(index) / 10.0
        assert_true(
            first.at(coordinate).stored_bytes() == second.at(coordinate).stored_bytes()
        )


def test_sample_and_colors_match_colormap_contracts() raises:
    var gradient = _black_to_white(MixSpace.STORED)
    assert_true(gradient.sample(0, 1) == gradient.at(0.0))
    assert_true(gradient.sample(0, 5) == gradient.at(0.0))
    assert_true(gradient.sample(4, 5) == gradient.at(1.0))

    with assert_raises(contains="sample count must be positive; got 0"):
        _ = gradient.sample(0, 0)
    with assert_raises(contains="sample count must be positive; got -1"):
        _ = gradient.sample(0, -1)
    with assert_raises(contains="sample index must be within [0, 5); got 5"):
        _ = gradient.sample(5, 5)
    with assert_raises(contains="sample index must be within [0, 5); got -1"):
        _ = gradient.sample(-1, 5)

    assert_true(len(gradient.colors(0)) == 0)
    assert_true(len(gradient.colors(-2)) == 0)
    var singleton = gradient.colors(1)
    assert_true(len(singleton) == 1)
    assert_true(singleton[0] == gradient.at(0.0))
    var three = gradient.colors(3)
    assert_true(len(three) == 3)
    assert_true(three[0] == gradient.at(0.0))
    assert_true(three[1] == gradient.at(0.5))
    assert_true(three[2] == gradient.at(1.0))


def test_alpha_interpolates_in_stored_space_for_every_mode() raises:
    var stored_stops: List[RGBA] = [RGBA.TRANSPARENT, RGBA.WHITE]
    var stored = Gradient(stored_stops^, MixSpace.STORED)
    assert_true(stored.at(0.5).alpha() == 0.5)

    var linear_stops: List[RGBA] = [RGBA.TRANSPARENT, RGBA.WHITE]
    var linear = Gradient(linear_stops^, MixSpace.LINEAR)
    assert_true(linear.at(0.5).alpha() == 0.5)

    var oklab_stops: List[RGBA] = [RGBA.TRANSPARENT, RGBA.WHITE]
    var oklab = Gradient(oklab_stops^, MixSpace.OKLAB)
    assert_true(oklab.at(0.5).alpha() == 0.5)
    assert_true(String(oklab) == "Gradient(2 stops, oklab)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
