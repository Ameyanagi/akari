from akari import RGBA
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


def test_components_are_preserved() raises:
    var color = RGBA(0.1, 0.2, 0.3, 0.4)
    assert_true(_near(color.red(), 0.1))
    assert_true(_near(color.green(), 0.2))
    assert_true(_near(color.blue(), 0.3))
    assert_true(_near(color.alpha(), 0.4))


def test_lerp_preserves_endpoints_and_interpolates_alpha() raises:
    var start = RGBA(0.0, 0.2, 1.0, 0.0)
    var end = RGBA(1.0, 0.6, 0.0, 1.0)
    assert_true(start.lerp(end, 0.0) == start)
    assert_true(start.lerp(end, 1.0) == end)
    var midpoint = start.lerp(end, 0.5)
    assert_true(_near(midpoint.red(), 0.5))
    assert_true(_near(midpoint.green(), 0.4))
    assert_true(_near(midpoint.blue(), 0.5))
    assert_true(_near(midpoint.alpha(), 0.5))


def test_invalid_components_and_amounts_raise() raises:
    with assert_raises(contains="red must be finite and within [0, 1]; got -0.1"):
        _ = RGBA(-0.1, 0.0, 0.0)
    with assert_raises(contains="alpha must be finite and within [0, 1]; got 1.1"):
        _ = RGBA(0.0, 0.0, 0.0, 1.1)
    with assert_raises(contains="red must be finite and within [0, 1]; got nan"):
        _ = RGBA(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="red must be finite and within [0, 1]; got inf"):
        _ = RGBA(Float64("inf"), 0.0, 0.0)
    with assert_raises(contains="red must be finite and within [0, 1]; got -inf"):
        _ = RGBA(Float64("-inf"), 0.0, 0.0)
    var black = RGBA.BLACK
    var transparent = RGBA.TRANSPARENT
    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got 1.01"
    ):
        _ = black.lerp(transparent, 1.01)
    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got nan"
    ):
        _ = black.lerp(transparent, Float64("nan"))
    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got inf"
    ):
        _ = black.lerp(transparent, Float64("inf"))


def test_validate_rejects_mutated_storage() raises:
    var corrupted = RGBA(0.1, 0.2, 0.3, 0.4)
    corrupted._red = Float64("nan")
    with assert_raises(contains="red must be finite and within [0, 1]; got nan"):
        corrupted.validate()

    var invalid_alpha = RGBA.BLACK
    invalid_alpha._alpha = 2.0
    with assert_raises(contains="alpha must be finite and within [0, 1]; got 2.0"):
        invalid_alpha.validate()


def test_exact_equality() raises:
    var black = RGBA.BLACK
    var other_black = RGBA.BLACK
    var transparent = RGBA.TRANSPARENT
    var red = RGBA.RED
    var blue = RGBA.BLUE
    assert_true(black == other_black)
    assert_true(black != transparent)
    assert_true(red != blue)


def test_string_representation() raises:
    assert_true(String(RGBA(0.1, 0.2, 0.3, 0.4)) == "RGBA(0.1, 0.2, 0.3, 0.4)")


def test_named_colors() raises:
    var black = RGBA.BLACK
    var transparent = RGBA.TRANSPARENT
    var white = RGBA.WHITE
    var red = RGBA.RED
    var green = RGBA.GREEN
    var blue = RGBA.BLUE
    assert_true(black == RGBA(0.0, 0.0, 0.0, 1.0))
    assert_true(transparent == RGBA(0.0, 0.0, 0.0, 0.0))
    assert_true(white == RGBA(1.0, 1.0, 1.0, 1.0))
    assert_true(red == RGBA(1.0, 0.0, 0.0, 1.0))
    assert_true(green == RGBA(0.0, 1.0, 0.0, 1.0))
    assert_true(blue == RGBA(0.0, 0.0, 1.0, 1.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
