"""Exercise Akari alpha/transfer boundaries in Kagerou path rasterization."""

from akari import PremultipliedRGBA, RGBA
from kagerou import PathBuilder, Rect, Rgba8, Surface
from std.testing import assert_equal, assert_raises, assert_true


def kagerou_pixel(color: PremultipliedRGBA) raises -> Rgba8:
    # Both nominal types store premultiplied channels. Quantize exactly once.
    var channels = color.stored_bytes()
    return Rgba8(channels[0], channels[1], channels[2], channels[3])


def check_raster(source: Rgba8, expected: Rgba8) raises:
    var path = PathBuilder.rectangle(Rect(1.0, 1.0, 5.0, 3.0))
    var surface = Surface(6, 4)
    surface.blend_path(path, source)
    for y in range(4):
        for x in range(6):
            if x >= 1 and x < 5 and y >= 1 and y < 3:
                assert_equal(surface.pixel(x, y), expected)
            else:
                assert_equal(surface.pixel(x, y), Rgba8(0, 0, 0, 0))
    surface.validate()


def main() raises:
    var straight = RGBA(0.5, 0.25, 0.75, 0.5)
    assert_true(straight.stored_bytes() == SIMD[DType.uint8, 4](128, 64, 191, 128))
    # Straight bytes are not valid premultiplied pixels (blue exceeds alpha).
    with assert_raises(contains="must not exceed alpha"):
        var bytes = straight.stored_bytes()
        _ = Rgba8(bytes[0], bytes[1], bytes[2], bytes[3])

    var stored = straight.premultiplied()
    assert_equal(stored.straight(), straight)
    var stored_pixel = kagerou_pixel(stored)
    assert_equal(stored_pixel, Rgba8(64, 32, 96, 128))
    check_raster(stored_pixel, Rgba8(64, 32, 96, 128))

    # Select encoded sRGB explicitly, decode before premultiplication, and
    # carry the original straight alpha across this RGB-only conversion.
    var linear = straight.to_srgb().to_linear()
    # Mojo 1.0's optimized power operation needs a 1e-9 absolute tolerance;
    # the downstream byte and raster assertions below remain exact.
    assert_true(abs(linear.red() - 0.21404114048223255) <= 1e-9)
    assert_true(abs(linear.green() - 0.05087608817155679) <= 1e-9)
    assert_true(abs(linear.blue() - 0.5225215539683921) <= 1e-9)
    var linear_straight = RGBA(
        linear.red(), linear.green(), linear.blue(), straight.alpha()
    )
    var linear_pixel = kagerou_pixel(linear_straight.premultiplied())
    assert_equal(linear_pixel, Rgba8(27, 6, 67, 128))
    check_raster(linear_pixel, Rgba8(27, 6, 67, 128))

    # Kagerou composites the supplied bytes; it does not apply an sRGB transfer.
    var path = PathBuilder.rectangle(Rect(1.0, 1.0, 5.0, 3.0))
    var stored_surface = Surface(6, 4)
    stored_surface.clear(Rgba8(255, 255, 255, 255))
    stored_surface.blend_path(path, stored_pixel)
    assert_equal(stored_surface.pixel(2, 2), Rgba8(191, 159, 223, 255))
    assert_equal(stored_surface.pixel(0, 0), Rgba8(255, 255, 255, 255))
    var linear_surface = Surface(6, 4)
    linear_surface.clear(Rgba8(255, 255, 255, 255))
    linear_surface.blend_path(path, linear_pixel)
    assert_equal(linear_surface.pixel(2, 2), Rgba8(154, 133, 194, 255))
    assert_equal(linear_surface.pixel(0, 0), Rgba8(255, 255, 255, 255))

    var transparent = kagerou_pixel(RGBA(1.0, 0.5, 0.25, 0.0).premultiplied())
    assert_equal(transparent, Rgba8(0, 0, 0, 0))
    stored_surface.blend_path(path, transparent)
    assert_equal(stored_surface.pixel(2, 2), Rgba8(191, 159, 223, 255))
    stored_surface.validate()
    linear_surface.validate()
    print("PASS Kagerou: decoded RGB=", linear.red(), linear.green(), linear.blue())
    print("PASS Kagerou: stored transparent=", stored_pixel)
    print("PASS Kagerou: linear transparent=", linear_pixel)
    print("PASS Kagerou: stored over white=", stored_surface.pixel(2, 2))
    print("PASS Kagerou: linear over white=", linear_surface.pixel(2, 2))
