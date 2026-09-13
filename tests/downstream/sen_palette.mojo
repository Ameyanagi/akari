"""Consume Akari's public palette/colormap API through Sen's SVG backend."""

from akari import Colormap, Palette, RGBA
from sen import Plot, SeriesStyle
from std.collections import List
from std.testing import assert_equal


def sen_style(color: RGBA) raises -> SeriesStyle:
    # These palette/table values represent encoded sRGB. Sen accepts #rrggbb
    # and straight opacity separately; neither premultiply nor decode here.
    return SeriesStyle(color=color.to_srgb().hex()).with_opacity(color.alpha())


def main() raises:
    var category = Palette.category10()[0]
    var low = Colormap.VIRIDIS.at(0.0)
    var middle = Colormap.VIRIDIS.at(128.0 / 255.0)
    var high = Colormap.VIRIDIS.at(1.0)
    assert_equal(category.hex(), "#1f77b4ff")
    assert_equal(low.hex(), "#440154ff")
    assert_equal(middle.hex(), "#21918cff")
    assert_equal(high.hex(), "#fde725ff")

    var x: List[Float64] = [0.0, 1.0, 2.0]
    var y0: List[Float64] = [0.0, 0.5, 1.0]
    var y1: List[Float64] = [1.0, 1.5, 2.0]
    var y2: List[Float64] = [2.0, 2.5, 3.0]
    var y3: List[Float64] = [3.0, 3.5, 4.0]
    var plot = Plot()
    plot.line(x, y0, label="Category10[0]", style=sen_style(category))
    plot.line(x, y1, label="viridis(0)", style=sen_style(low))
    plot.line(x, y2, label="viridis(128/255)", style=sen_style(middle))
    # Exercise the separate opacity boundary on a non-opaque colormap color.
    var translucent_high = high.to_srgb().to_rgba(0.5)
    plot.line(x, y3, label="viridis(1), alpha=0.5", style=sen_style(translucent_high))
    plot.title("Akari colors consumed by pinned Sen")
    plot.xlabel("sample")
    plot.ylabel("response")
    plot.save_svg("sen.svg", 640.0, 400.0)
    print("PASS Sen: Category10 and viridis numeric values; wrote sen.svg")
