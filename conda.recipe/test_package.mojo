from akari import PremultipliedRGBA, RGBA
from std.testing import assert_true


def main() raises:
    var midpoint = RGBA(0.0, 0.2, 1.0, 0.0).lerp(RGBA(1.0, 0.6, 0.0, 1.0), 0.5)
    assert_true(midpoint.red() == 0.5)
    assert_true(midpoint.green() == 0.4)
    assert_true(midpoint.blue() == 0.5)
    assert_true(midpoint.alpha() == 0.5)
    var premultiplied: PremultipliedRGBA = midpoint.premultiplied()
    assert_true(premultiplied.straight() == midpoint)
