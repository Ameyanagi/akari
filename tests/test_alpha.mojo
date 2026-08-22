from akari import PremultipliedRGBA, RGBA
from std.testing import TestSuite, assert_raises, assert_true


def _near(left: Float64, right: Float64, tolerance: Float64 = 1e-12) -> Bool:
    return abs(left - right) <= tolerance


def test_straight_to_premultiplied_and_back() raises:
    var straight = RGBA(0.8, 0.4, 0.2, 0.5)
    var premultiplied = straight.premultiplied()
    assert_true(_near(premultiplied.red(), 0.4))
    assert_true(_near(premultiplied.green(), 0.2))
    assert_true(_near(premultiplied.blue(), 0.1))
    assert_true(_near(premultiplied.alpha(), 0.5))
    var restored = premultiplied.straight()
    assert_true(_near(restored.red(), straight.red()))
    assert_true(_near(restored.green(), straight.green()))
    assert_true(_near(restored.blue(), straight.blue()))
    assert_true(_near(restored.alpha(), straight.alpha()))


def test_transparent_premultiplication_canonicalizes_hidden_rgb() raises:
    var transparent = RGBA(1.0, 0.25, 0.75, 0.0).premultiplied()
    assert_true(transparent == PremultipliedRGBA.TRANSPARENT)
    assert_true(transparent.straight() == RGBA.TRANSPARENT)


def test_premultiplied_constructor_and_validate_enforce_invariant() raises:
    with assert_raises(contains="red must not exceed alpha in premultiplied RGBA"):
        _ = PremultipliedRGBA(0.6, 0.1, 0.1, 0.5)
    with assert_raises(contains="blue must be finite and within [0, 1]; got nan"):
        _ = PremultipliedRGBA(0.0, 0.0, Float64("nan"), 0.5)

    var corrupted = PremultipliedRGBA(0.25, 0.1, 0.0, 0.5)
    corrupted._green = 0.75
    with assert_raises(contains="green must not exceed alpha"):
        corrupted.validate()


def test_premultiplied_grid_round_trips_for_nonzero_alpha() raises:
    for alpha_step in range(1, 17):
        var alpha = Float64(alpha_step) / 16.0
        for red_step in range(17):
            for green_step in range(0, 17, 4):
                for blue_step in range(0, 17, 4):
                    var straight = RGBA(
                        Float64(red_step) / 16.0,
                        Float64(green_step) / 16.0,
                        Float64(blue_step) / 16.0,
                        alpha,
                    )
                    var restored = straight.premultiplied().straight()
                    assert_true(_near(restored.red(), straight.red()))
                    assert_true(_near(restored.green(), straight.green()))
                    assert_true(_near(restored.blue(), straight.blue()))
                    assert_true(_near(restored.alpha(), straight.alpha()))


def test_premultiplied_stored_bytes_are_explicit() raises:
    var premultiplied = RGBA(1.0, 0.5, 0.0, 0.5).premultiplied()
    var bytes = premultiplied.stored_bytes()
    assert_true(bytes[0] == UInt8(128))
    assert_true(bytes[1] == UInt8(64))
    assert_true(bytes[2] == UInt8(0))
    assert_true(bytes[3] == UInt8(128))


def test_premultiplied_stored_byte_import_round_trips_and_validates() raises:
    var color = PremultipliedRGBA.from_stored_bytes(64, 32, 0, 128)
    assert_true(color.stored_bytes() == SIMD[DType.uint8, 4](64, 32, 0, 128))
    with assert_raises(contains="red must not exceed alpha in premultiplied RGBA"):
        _ = PremultipliedRGBA.from_stored_bytes(129, 0, 0, 128)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
