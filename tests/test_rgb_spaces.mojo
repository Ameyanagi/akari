from akari import Hsl, Hsv, LinearSrgb, Srgb
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    return difference <= tolerance


def _hue_near(left: Float64, right: Float64, tolerance: Float64 = 1e-9) -> Bool:
    var difference = left - right
    if difference < 0.0:
        difference = -difference
    if difference > 180.0:
        difference = 360.0 - difference
    return difference <= tolerance


def _assert_srgb_near(actual: Srgb, expected: Srgb, tolerance: Float64 = 1e-12) raises:
    assert_true(_near(actual.red(), expected.red(), tolerance))
    assert_true(_near(actual.green(), expected.green(), tolerance))
    assert_true(_near(actual.blue(), expected.blue(), tolerance))


def _assert_srgb_range(color: Srgb) raises:
    assert_true(color.red() >= 0.0 and color.red() <= 1.0)
    assert_true(color.green() >= 0.0 and color.green() <= 1.0)
    assert_true(color.blue() >= 0.0 and color.blue() <= 1.0)


def _assert_linear_range(color: LinearSrgb) raises:
    assert_true(color.red() >= 0.0 and color.red() <= 1.0)
    assert_true(color.green() >= 0.0 and color.green() <= 1.0)
    assert_true(color.blue() >= 0.0 and color.blue() <= 1.0)


def _assert_hsl_range(color: Hsl) raises:
    assert_true(color.hue() >= 0.0 and color.hue() < 360.0)
    assert_true(color.saturation() >= 0.0 and color.saturation() <= 1.0)
    assert_true(color.lightness() >= 0.0 and color.lightness() <= 1.0)


def _assert_hsv_range(color: Hsv) raises:
    assert_true(color.hue() >= 0.0 and color.hue() < 360.0)
    assert_true(color.saturation() >= 0.0 and color.saturation() <= 1.0)
    assert_true(color.value() >= 0.0 and color.value() <= 1.0)


def _assert_hsl_fixture(
    rgb: Srgb, hue: Float64, saturation: Float64, lightness: Float64
) raises:
    var converted = rgb.to_hsl()
    assert_true(_near(converted.hue(), hue))
    assert_true(_near(converted.saturation(), saturation))
    assert_true(_near(converted.lightness(), lightness))
    _assert_srgb_near(Hsl(hue, saturation, lightness).to_srgb(), rgb)


def _assert_hsv_fixture(
    rgb: Srgb, hue: Float64, saturation: Float64, value: Float64
) raises:
    var converted = rgb.to_hsv()
    assert_true(_near(converted.hue(), hue))
    assert_true(_near(converted.saturation(), saturation))
    assert_true(_near(converted.value(), value))
    _assert_srgb_near(Hsv(hue, saturation, value).to_srgb(), rgb)


def test_constructor_boundaries() raises:
    with assert_raises(contains="red must be finite"):
        _ = Srgb(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="green must be finite"):
        _ = Srgb(0.0, Float64("inf"), 0.0)
    with assert_raises(contains="blue must be finite"):
        _ = Srgb(0.0, 0.0, Float64("-inf"))
    with assert_raises(contains="red must be finite"):
        _ = Srgb(-0.01, 0.0, 0.0)
    with assert_raises(contains="blue must be finite"):
        _ = Srgb(0.0, 0.0, 1.01)

    with assert_raises(contains="red must be finite"):
        _ = LinearSrgb(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="green must be finite"):
        _ = LinearSrgb(0.0, Float64("inf"), 0.0)
    with assert_raises(contains="blue must be finite"):
        _ = LinearSrgb(0.0, 0.0, Float64("-inf"))
    with assert_raises(contains="green must be finite"):
        _ = LinearSrgb(0.0, -0.01, 0.0)
    with assert_raises(contains="blue must be finite"):
        _ = LinearSrgb(0.0, 0.0, 1.01)

    with assert_raises(contains="hue must be finite"):
        _ = Hsl(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="hue must be finite"):
        _ = Hsl(Float64("inf"), 0.0, 0.0)
    with assert_raises(contains="hue must be finite"):
        _ = Hsl(Float64("-inf"), 0.0, 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsl(0.0, -0.01, 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsl(0.0, Float64("nan"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsl(0.0, Float64("inf"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsl(0.0, Float64("-inf"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsl(0.0, 1.01, 0.0)
    with assert_raises(contains="lightness must be finite"):
        _ = Hsl(0.0, 0.0, Float64("nan"))
    with assert_raises(contains="lightness must be finite"):
        _ = Hsl(0.0, 0.0, Float64("inf"))
    with assert_raises(contains="lightness must be finite"):
        _ = Hsl(0.0, 0.0, Float64("-inf"))
    with assert_raises(contains="lightness must be finite"):
        _ = Hsl(0.0, 0.0, -0.01)
    with assert_raises(contains="lightness must be finite"):
        _ = Hsl(0.0, 0.0, 1.01)

    with assert_raises(contains="hue must be finite"):
        _ = Hsv(Float64("nan"), 0.0, 0.0)
    with assert_raises(contains="hue must be finite"):
        _ = Hsv(Float64("inf"), 0.0, 0.0)
    with assert_raises(contains="hue must be finite"):
        _ = Hsv(Float64("-inf"), 0.0, 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsv(0.0, Float64("-inf"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsv(0.0, Float64("nan"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsv(0.0, Float64("inf"), 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsv(0.0, -0.01, 0.0)
    with assert_raises(contains="saturation must be finite"):
        _ = Hsv(0.0, 1.01, 0.0)
    with assert_raises(contains="value must be finite"):
        _ = Hsv(0.0, 0.0, Float64("nan"))
    with assert_raises(contains="value must be finite"):
        _ = Hsv(0.0, 0.0, Float64("inf"))
    with assert_raises(contains="value must be finite"):
        _ = Hsv(0.0, 0.0, Float64("-inf"))
    with assert_raises(contains="value must be finite"):
        _ = Hsv(0.0, 0.0, -0.01)
    with assert_raises(contains="value must be finite"):
        _ = Hsv(0.0, 0.0, 1.01)


def test_validate_rejects_direct_mutation() raises:
    var encoded_red = Srgb(0.1, 0.2, 0.3)
    encoded_red._red = Float64("nan")
    with assert_raises(contains="red must be finite"):
        encoded_red.validate()
    var encoded_green = Srgb(0.1, 0.2, 0.3)
    encoded_green._green = 2.0
    with assert_raises(contains="green must be finite"):
        encoded_green.validate()
    var encoded_blue = Srgb(0.1, 0.2, 0.3)
    encoded_blue._blue = -1.0
    with assert_raises(contains="blue must be finite"):
        encoded_blue.validate()

    var linear_red = LinearSrgb(0.1, 0.2, 0.3)
    linear_red._red = Float64("inf")
    with assert_raises(contains="red must be finite"):
        linear_red.validate()
    var linear_green = LinearSrgb(0.1, 0.2, 0.3)
    linear_green._green = -1.0
    with assert_raises(contains="green must be finite"):
        linear_green.validate()
    var linear_blue = LinearSrgb(0.1, 0.2, 0.3)
    linear_blue._blue = 2.0
    with assert_raises(contains="blue must be finite"):
        linear_blue.validate()

    var hsl_hue = Hsl(30.0, 0.5, 0.5)
    hsl_hue._hue = 360.0
    with assert_raises(contains="hue must be finite"):
        hsl_hue.validate()
    var hsl_saturation = Hsl(30.0, 0.5, 0.5)
    hsl_saturation._saturation = Float64("inf")
    with assert_raises(contains="saturation must be finite"):
        hsl_saturation.validate()
    var hsl_lightness = Hsl(30.0, 0.5, 0.5)
    hsl_lightness._lightness = -1.0
    with assert_raises(contains="lightness must be finite"):
        hsl_lightness.validate()

    var hsv_hue = Hsv(30.0, 0.5, 0.5)
    hsv_hue._hue = Float64("nan")
    with assert_raises(contains="hue must be finite"):
        hsv_hue.validate()
    var hsv_saturation = Hsv(30.0, 0.5, 0.5)
    hsv_saturation._saturation = -1.0
    with assert_raises(contains="saturation must be finite"):
        hsv_saturation.validate()
    var hsv_value = Hsv(30.0, 0.5, 0.5)
    hsv_value._value = Float64("inf")
    with assert_raises(contains="value must be finite"):
        hsv_value.validate()


def test_hue_normalization() raises:
    assert_true(Hsl(360.0, 0.5, 0.5) == Hsl(0.0, 0.5, 0.5))
    assert_true(Hsl(720.0, 0.5, 0.5) == Hsl(0.0, 0.5, 0.5))
    assert_true(Hsl(-90.0, 0.5, 0.5) == Hsl(270.0, 0.5, 0.5))
    assert_true(Hsv(360.0, 0.5, 0.5) == Hsv(0.0, 0.5, 0.5))
    assert_true(Hsv(720.0, 0.5, 0.5) == Hsv(0.0, 0.5, 0.5))
    assert_true(Hsv(-90.0, 0.5, 0.5) == Hsv(270.0, 0.5, 0.5))


def test_achromatic_conventions() raises:
    for index in range(9):
        var gray = Float64(index) / 8.0
        var rgb = Srgb(gray, gray, gray)
        var hsl = rgb.to_hsl()
        assert_true(hsl.hue() == 0.0)
        assert_true(hsl.saturation() == 0.0)
        assert_true(_near(hsl.lightness(), gray))
        var hsv = rgb.to_hsv()
        assert_true(hsv.hue() == 0.0)
        assert_true(hsv.saturation() == 0.0)
        assert_true(_near(hsv.value(), gray))

    for index in range(8):
        var hue = Float64(index) * 45.0
        _assert_srgb_near(Hsl(hue, 0.0, 0.25).to_srgb(), Srgb(0.25, 0.25, 0.25))
        _assert_srgb_near(Hsv(hue, 0.0, 0.75).to_srgb(), Srgb(0.75, 0.75, 0.75))


def test_hsl_primary_secondary_and_endpoint_fixtures() raises:
    _assert_hsl_fixture(Srgb(1.0, 0.0, 0.0), 0.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(1.0, 1.0, 0.0), 60.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(0.0, 1.0, 0.0), 120.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(0.0, 1.0, 1.0), 180.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(0.0, 0.0, 1.0), 240.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(1.0, 0.0, 1.0), 300.0, 1.0, 0.5)
    _assert_hsl_fixture(Srgb(0.0, 0.0, 0.0), 0.0, 0.0, 0.0)
    _assert_hsl_fixture(Srgb(1.0, 1.0, 1.0), 0.0, 0.0, 1.0)


def test_hsv_primary_secondary_and_endpoint_fixtures() raises:
    _assert_hsv_fixture(Srgb(1.0, 0.0, 0.0), 0.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(1.0, 1.0, 0.0), 60.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(0.0, 1.0, 0.0), 120.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(0.0, 1.0, 1.0), 180.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(0.0, 0.0, 1.0), 240.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(1.0, 0.0, 1.0), 300.0, 1.0, 1.0)
    _assert_hsv_fixture(Srgb(0.0, 0.0, 0.0), 0.0, 0.0, 0.0)
    _assert_hsv_fixture(Srgb(1.0, 1.0, 1.0), 0.0, 0.0, 1.0)


def test_transfer_breakpoints_endpoints_and_round_trip() raises:
    var decoded_at = Srgb(0.04045, 0.0, 0.0).to_linear().red()
    assert_true(_near(decoded_at, 0.04045 / 12.92, 1e-15))
    var decoded_below = Srgb(0.04045 - 1e-10, 0.0, 0.0).to_linear().red()
    assert_true(_near(decoded_below, (0.04045 - 1e-10) / 12.92, 1e-15))
    var encoded_just_above = Srgb(0.04045 + 1e-10, 0.0, 0.0)
    var decoded_above = encoded_just_above.to_linear().red()
    assert_true(
        _near(
            decoded_above,
            ((0.04045 + 1e-10 + 0.055) / 1.055) ** 2.4,
            1e-15,
        )
    )
    assert_true(_near(decoded_below, decoded_above, 1e-8))

    var encoded_at = LinearSrgb(0.0031308, 0.0, 0.0).to_encoded().red()
    assert_true(_near(encoded_at, 12.92 * 0.0031308, 1e-15))
    var encoded_below = LinearSrgb(0.0031308 - 1e-10, 0.0, 0.0).to_encoded().red()
    assert_true(_near(encoded_below, 12.92 * (0.0031308 - 1e-10), 1e-15))
    var linear_just_above = LinearSrgb(0.0031308 + 1e-10, 0.0, 0.0)
    var encoded_above = linear_just_above.to_encoded().red()
    assert_true(
        _near(
            encoded_above,
            1.055 * (0.0031308 + 1e-10) ** (1.0 / 2.4) - 0.055,
            1e-15,
        )
    )
    assert_true(_near(encoded_below, encoded_above, 1e-7))

    assert_true(Srgb(0.0, 0.0, 0.0).to_linear() == LinearSrgb(0.0, 0.0, 0.0))
    assert_true(Srgb(1.0, 1.0, 1.0).to_linear() == LinearSrgb(1.0, 1.0, 1.0))
    assert_true(LinearSrgb(0.0, 0.0, 0.0).to_encoded() == Srgb(0.0, 0.0, 0.0))
    assert_true(LinearSrgb(1.0, 1.0, 1.0).to_encoded() == Srgb(1.0, 1.0, 1.0))

    # Documented tolerance: Mojo 1.0 Float64 power evaluates with roughly 1e-9
    # relative accuracy, so the encode/decode round trip is bounded by 1e-8.
    for index in range(65):
        var component = Float64(index) / 64.0
        var linear = LinearSrgb(component, component, component)
        var encoded = linear.to_encoded()
        var recovered = encoded.to_linear()
        _assert_srgb_range(encoded)
        _assert_linear_range(recovered)
        assert_true(_near(recovered.red(), component, 1e-8))
        assert_true(_near(recovered.green(), component, 1e-8))
        assert_true(_near(recovered.blue(), component, 1e-8))


def test_rgb_cylindrical_round_trips_and_ranges() raises:
    for red_index in range(5):
        for green_index in range(5):
            for blue_index in range(5):
                var rgb = Srgb(
                    Float64(red_index) / 4.0,
                    Float64(green_index) / 4.0,
                    Float64(blue_index) / 4.0,
                )
                var hsl = rgb.to_hsl()
                var hsl_recovered = hsl.to_srgb()
                _assert_hsl_range(hsl)
                _assert_srgb_range(hsl_recovered)
                _assert_srgb_near(hsl_recovered, rgb, 1e-12)

                var hsv = rgb.to_hsv()
                var hsv_recovered = hsv.to_srgb()
                _assert_hsv_range(hsv)
                _assert_srgb_range(hsv_recovered)
                _assert_srgb_near(hsv_recovered, rgb, 1e-12)


def test_hsl_round_trip_where_hue_is_recoverable() raises:
    for hue_index in range(12):
        for saturation_index in range(1, 5):
            for lightness_index in range(1, 4):
                var original = Hsl(
                    Float64(hue_index) * 30.0,
                    Float64(saturation_index) / 4.0,
                    Float64(lightness_index) / 4.0,
                )
                var rgb = original.to_srgb()
                var recovered = rgb.to_hsl()
                _assert_srgb_range(rgb)
                _assert_hsl_range(recovered)
                assert_true(_hue_near(recovered.hue(), original.hue()))
                assert_true(_near(recovered.saturation(), original.saturation(), 1e-9))
                assert_true(_near(recovered.lightness(), original.lightness(), 1e-9))


def test_hsv_round_trip_where_hue_is_recoverable() raises:
    for hue_index in range(12):
        for saturation_index in range(1, 5):
            for value_index in range(1, 5):
                var original = Hsv(
                    Float64(hue_index) * 30.0,
                    Float64(saturation_index) / 4.0,
                    Float64(value_index) / 4.0,
                )
                var rgb = original.to_srgb()
                var recovered = rgb.to_hsv()
                _assert_srgb_range(rgb)
                _assert_hsv_range(recovered)
                assert_true(_hue_near(recovered.hue(), original.hue()))
                assert_true(_near(recovered.saturation(), original.saturation(), 1e-9))
                assert_true(_near(recovered.value(), original.value(), 1e-9))


def test_exact_equality_and_string_representations() raises:
    assert_true(Srgb(0.1, 0.2, 0.3) == Srgb(0.1, 0.2, 0.3))
    assert_true(LinearSrgb(0.1, 0.2, 0.3) != LinearSrgb(0.3, 0.2, 0.1))
    assert_true(String(Srgb(0.1, 0.2, 0.3)) == "Srgb(0.1, 0.2, 0.3)")
    assert_true(String(LinearSrgb(0.1, 0.2, 0.3)) == "LinearSrgb(0.1, 0.2, 0.3)")
    assert_true(String(Hsl(30.0, 0.5, 0.25)) == "Hsl(30.0, 0.5, 0.25)")
    assert_true(String(Hsv(30.0, 0.5, 0.25)) == "Hsv(30.0, 0.5, 0.25)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
