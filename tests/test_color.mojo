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
    with assert_raises(contains="red must be finite"):
        _ = RGBA(-0.1, 0.0, 0.0)
    with assert_raises(contains="alpha must be finite"):
        _ = RGBA(0.0, 0.0, 0.0, 1.1)
    with assert_raises(contains="red must be finite"):
        _ = RGBA(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="red must be finite"):
        _ = RGBA(Float64("inf"), 0.0, 0.0)
    with assert_raises(contains="red must be finite"):
        _ = RGBA(Float64("-inf"), 0.0, 0.0)
    var black = RGBA.black()
    with assert_raises(contains="interpolation amount must be finite"):
        _ = black.lerp(RGBA.transparent(), 1.01)
    with assert_raises(contains="interpolation amount must be finite"):
        _ = black.lerp(RGBA.transparent(), Float64("nan"))
    with assert_raises(contains="interpolation amount must be finite"):
        _ = black.lerp(RGBA.transparent(), Float64("inf"))


def test_validate_rejects_mutated_storage() raises:
    var corrupted = RGBA(0.1, 0.2, 0.3, 0.4)
    corrupted._red = Float64("nan")
    with assert_raises(contains="red must be finite"):
        corrupted.validate()

    var invalid_alpha = RGBA.black()
    invalid_alpha._alpha = 2.0
    with assert_raises(contains="alpha must be finite"):
        invalid_alpha.validate()


def test_exact_equality() raises:
    assert_true(RGBA.black() == RGBA.black())
    assert_true(RGBA.black() != RGBA.transparent())
    assert_true(RGBA.red_color() != RGBA.blue_color())


def test_string_representation() raises:
    assert_true(String(RGBA(0.1, 0.2, 0.3, 0.4)) == "RGBA(0.1, 0.2, 0.3, 0.4)")


def test_named_colors() raises:
    assert_true(RGBA.black() == RGBA(0.0, 0.0, 0.0, 1.0))
    assert_true(RGBA.transparent() == RGBA(0.0, 0.0, 0.0, 0.0))
    assert_true(RGBA.white() == RGBA(1.0, 1.0, 1.0, 1.0))
    assert_true(RGBA.red_color() == RGBA(1.0, 0.0, 0.0, 1.0))
    assert_true(RGBA.green_color() == RGBA(0.0, 1.0, 0.0, 1.0))
    assert_true(RGBA.blue_color() == RGBA(0.0, 0.0, 1.0, 1.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
