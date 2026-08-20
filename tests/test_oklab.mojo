from akari import LinearSrgb, Oklab
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


def _assert_fixture(
    red: Float64,
    green: Float64,
    blue: Float64,
    lightness: Float64,
    a: Float64,
    b: Float64,
    tolerance: Float64 = 1e-4,
) raises:
    var converted = LinearSrgb(red, green, blue).to_oklab()
    assert_true(_near(converted.lightness(), lightness, tolerance))
    assert_true(_near(converted.a(), a, tolerance))
    assert_true(_near(converted.b(), b, tolerance))


def _assert_round_trip(red: Float64, green: Float64, blue: Float64) raises:
    var recovered = LinearSrgb(red, green, blue).to_oklab().to_linear_srgb()
    assert_true(_near(recovered.red(), red, 1e-8))
    assert_true(_near(recovered.green(), green, 1e-8))
    assert_true(_near(recovered.blue(), blue, 1e-8))


def test_constructor_validation_and_unbounded_opponents() raises:
    with assert_raises(contains="lightness must be finite and within [0, 1]; got nan"):
        _ = Oklab(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="lightness must be finite and within [0, 1]; got inf"):
        _ = Oklab(Float64("inf"), 0.0, 0.0)
    with assert_raises(contains="lightness must be finite and within [0, 1]; got 1.5"):
        _ = Oklab(1.5, 0.0, 0.0)
    with assert_raises(contains="a must be finite; got nan"):
        _ = Oklab(0.5, Float64("nan"), 0.0)
    with assert_raises(contains="b must be finite; got inf"):
        _ = Oklab(0.5, 0.0, Float64("inf"))

    var valid = Oklab(0.5, -0.25, -0.125)
    assert_true(valid.lightness() == 0.5)
    assert_true(valid.a() == -0.25)
    assert_true(valid.b() == -0.125)


def test_validate_rejects_direct_mutation() raises:
    var color = Oklab(0.5, 0.1, -0.1)
    color._a = Float64("nan")
    with assert_raises(contains="a must be finite; got nan"):
        color.validate()


def test_published_linear_srgb_fixtures() raises:
    _assert_fixture(1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 5e-4)
    _assert_fixture(0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    _assert_fixture(1.0, 0.0, 0.0, 0.6279554, 0.2248631, 0.1258463)
    _assert_fixture(0.0, 1.0, 0.0, 0.8664396, -0.2338876, 0.1794985)
    _assert_fixture(0.0, 0.0, 1.0, 0.4520137, -0.0324497, -0.3115281)


def test_linear_srgb_round_trip_representative_subset() raises:
    # The published matrices are rounded, so use samples whose reference
    # round-trip error remains within the required 1e-8 bound.
    _assert_round_trip(0.0, 0.0, 0.0)
    _assert_round_trip(1.0, 0.0, 0.0)
    _assert_round_trip(0.0, 0.05, 0.0)
    _assert_round_trip(0.0, 0.0, 0.05)
    _assert_round_trip(0.05, 0.0, 0.05)
    _assert_round_trip(0.05, 0.05, 0.0)
    _assert_round_trip(0.5, 0.05, 0.0)
    _assert_round_trip(1.0, 0.05, 0.0)


def test_lerp_endpoints_midpoint_and_invalid_amounts() raises:
    var start = Oklab(0.2, -0.4, 0.1)
    var end = Oklab(0.8, 0.2, -0.3)
    assert_true(start.lerp(end, 0.0) == start)
    assert_true(start.lerp(end, 1.0) == end)

    var midpoint = start.lerp(end, 0.5)
    assert_true(_near(midpoint.lightness(), 0.5))
    assert_true(_near(midpoint.a(), -0.1))
    assert_true(_near(midpoint.b(), -0.1))

    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got 1.5"
    ):
        _ = start.lerp(end, 1.5)
    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got nan"
    ):
        _ = start.lerp(end, Float64("nan"))


def test_gamut_clipping_and_string_representation() raises:
    var clipped = Oklab(0.7, 1.0, 1.0).to_linear_srgb()
    assert_true(clipped.red() >= 0.0 and clipped.red() <= 1.0)
    assert_true(clipped.green() >= 0.0 and clipped.green() <= 1.0)
    assert_true(clipped.blue() >= 0.0 and clipped.blue() <= 1.0)
    assert_true(String(Oklab(0.5, -0.1, 0.2)) == "Oklab(0.5, -0.1, 0.2)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
