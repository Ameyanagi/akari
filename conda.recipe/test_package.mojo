from akari import Colormap, Gradient, Palette, PremultipliedRGBA, RGBA
from std.collections import List
from std.testing import assert_true


def main() raises:
    var midpoint = RGBA(0.0, 0.2, 1.0, 0.0).lerp(RGBA(1.0, 0.6, 0.0, 1.0), 0.5)
    assert_true(midpoint.red() == 0.5)
    assert_true(midpoint.green() == 0.4)
    assert_true(midpoint.blue() == 0.5)
    assert_true(midpoint.alpha() == 0.5)
    var premultiplied: PremultipliedRGBA = midpoint.premultiplied()
    assert_true(premultiplied.straight() == midpoint)

    var mapped = Colormap.VIRIDIS.at(0.5)
    assert_true(mapped.alpha() == 1.0)

    var palette = Palette.tableau10()
    assert_true(len(palette) == 10)
    assert_true(palette.cycle(10) == palette[0])

    var stops: List[RGBA] = [RGBA.BLACK, RGBA.WHITE]
    var gradient = Gradient(stops^)
    assert_true(gradient.at(0.0) == RGBA.BLACK)
    assert_true(gradient.at(1.0) == RGBA.WHITE)
