from akari import Gradient, MixSpace, RGBA
from std.collections import List
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


def test_rgba_srgb_bridge_preserves_rgb_and_controls_alpha() raises:
    var rgba = RGBA(0.2, 0.4, 0.6, 0.5)
    var encoded = rgba.to_srgb()
    assert_true(encoded.red() == 0.2)
    assert_true(encoded.green() == 0.4)
    assert_true(encoded.blue() == 0.6)

    var opaque = encoded.to_rgba()
    assert_true(opaque.red() == encoded.red())
    assert_true(opaque.green() == encoded.green())
    assert_true(opaque.blue() == encoded.blue())
    assert_true(opaque.alpha() == 1.0)

    var translucent = encoded.to_rgba(0.25)
    assert_true(translucent.red() == encoded.red())
    assert_true(translucent.green() == encoded.green())
    assert_true(translucent.blue() == encoded.blue())
    assert_true(translucent.alpha() == 0.25)

    with assert_raises(contains="alpha must be finite and within [0, 1]; got 1.5"):
        _ = encoded.to_rgba(1.5)
    with assert_raises(
        contains=(
            "alpha must be finite and within [0, 1]; got 255.0; for 0-255 byte"
            " components use from_stored_bytes"
        )
    ):
        _ = encoded.to_rgba(255.0)


def test_hex_import_supported_forms() raises:
    assert_true(
        RGBA.from_hex("#1f77b4")
        == RGBA.from_stored_bytes(UInt8(0x1F), UInt8(0x77), UInt8(0xB4))
    )
    assert_true(RGBA.from_hex("#ABC") == RGBA.from_hex("#aabbcc"))
    assert_true(
        RGBA.from_hex("#11223344")
        == RGBA.from_stored_bytes(UInt8(0x11), UInt8(0x22), UInt8(0x33), UInt8(0x44))
    )


def test_hex_import_rejects_every_invalid_shape_or_digit() raises:
    with assert_raises(
        contains='hex color must be #rgb, #rrggbb, or #rrggbbaa; got "1f77b4"'
    ):
        _ = RGBA.from_hex("1f77b4")
    with assert_raises(
        contains='hex color must be #rgb, #rrggbb, or #rrggbbaa; got "#1f77b"'
    ):
        _ = RGBA.from_hex("#1f77b")
    with assert_raises(
        contains='hex color must be #rgb, #rrggbb, or #rrggbbaa; got "#1g77b4"'
    ):
        _ = RGBA.from_hex("#1g77b4")
    with assert_raises(
        contains='hex color must be #rgb, #rrggbb, or #rrggbbaa; got ""'
    ):
        _ = RGBA.from_hex("")


def test_hex_rgb_uses_strict_rgb_quantization() raises:
    var color = RGBA.from_stored_bytes(UInt8(0x44), UInt8(0x01), UInt8(0x54))
    assert_true(color.hex_rgb() == "#440154")
    var rgba_hex = color.hex()
    assert_true(color.hex_rgb() == String(rgba_hex[byte=0:7]))


def test_mix_stored_matches_lerp_and_defaults_to_stored() raises:
    var start = RGBA(0.1, 0.7, 0.3, 0.2)
    var end = RGBA(0.9, 0.2, 0.8, 0.6)
    var amounts: List[Float64] = [0.0, 0.25, 0.5, 1.0]
    for amount in amounts:
        assert_true(start.mix(end, amount, MixSpace.STORED) == start.lerp(end, amount))
        assert_true(start.mix(end, amount) == start.lerp(end, amount))


def test_mix_oklab_matches_gradient_and_validates_amount() raises:
    var start = RGBA(0.1, 0.7, 0.3, 0.2)
    var end = RGBA(0.9, 0.2, 0.8, 0.6)
    var stops: List[RGBA] = [start, end]
    var gradient = Gradient(stops^, MixSpace.OKLAB)
    assert_true(start.mix(end, 0.5, MixSpace.OKLAB) == gradient.at(0.5))
    with assert_raises(
        contains="interpolation amount must be finite and within [0, 1]; got 1.5"
    ):
        _ = start.mix(end, 1.5, MixSpace.OKLAB)


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


def test_byte_scale_components_point_to_stored_byte_import() raises:
    with assert_raises(
        contains=(
            "red must be finite and within [0, 1]; got 255.0; for 0-255 byte components"
            " use from_stored_bytes"
        )
    ):
        _ = RGBA(255.0, 128.0, 0.0)
    with assert_raises(
        contains=(
            "alpha must be finite and within [0, 1]; got 42.0; for 0-255 byte"
            " components use from_stored_bytes"
        )
    ):
        _ = RGBA(0.0, 0.0, 0.0, 42.0)
    with assert_raises(contains="red must be finite and within [0, 1]; got 1.5"):
        _ = RGBA(1.5, 0.0, 0.0)
    with assert_raises(
        contains=(
            "red must be finite and within [0, 1]; got 2.0; for 0-255 byte components"
            " use from_stored_bytes"
        )
    ):
        _ = RGBA(2.0, 0.0, 0.0)
    with assert_raises(contains="red must be finite and within [0, 1]; got 256.0"):
        _ = RGBA(256.0, 0.0, 0.0)


def test_validate_rejects_mutated_storage() raises:
    var corrupted = RGBA(0.1, 0.2, 0.3, 0.4)
    corrupted._red = Float64("nan")
    with assert_raises(contains="red must be finite and within [0, 1]; got nan"):
        corrupted.validate()

    var invalid_alpha = RGBA.BLACK
    invalid_alpha._alpha = 2.0
    with assert_raises(
        contains=(
            "alpha must be finite and within [0, 1]; got 2.0; for 0-255 byte components"
            " use from_stored_bytes"
        )
    ):
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
