from akari import Palette, RGBA, Srgb
from std.collections import List
from std.testing import TestSuite, assert_raises, assert_true


def _assert_palette_bytes(
    palette: Palette,
    index: Int,
    red: Int,
    green: Int,
    blue: Int,
) raises:
    var expected = SIMD[DType.uint8, 4](
        UInt8(red), UInt8(green), UInt8(blue), UInt8(255)
    )
    assert_true(palette[index].stored_bytes() == expected)


def test_constructor_rejects_empty_and_accepts_single_color() raises:
    var empty = List[RGBA]()
    with assert_raises(contains="palette needs at least 1 color; got 0"):
        _ = Palette(empty^)

    var colors: List[RGBA] = [RGBA.RED]
    var singleton = Palette(colors^)
    assert_true(len(singleton) == 1)
    assert_true(singleton[0] == RGBA.RED)
    assert_true(singleton.cycle(0) == RGBA.RED)
    assert_true(singleton.cycle(17) == RGBA.RED)
    assert_true(singleton.cycle(-17) == RGBA.RED)


def test_category10_exact_data_and_strict_indexing() raises:
    var palette = Palette.category10()
    assert_true(len(palette) == 10)
    _assert_palette_bytes(palette, 0, 0x1F, 0x77, 0xB4)
    _assert_palette_bytes(palette, 1, 0xFF, 0x7F, 0x0E)
    _assert_palette_bytes(palette, 2, 0x2C, 0xA0, 0x2C)
    _assert_palette_bytes(palette, 3, 0xD6, 0x27, 0x28)
    _assert_palette_bytes(palette, 4, 0x94, 0x67, 0xBD)
    _assert_palette_bytes(palette, 5, 0x8C, 0x56, 0x4B)
    _assert_palette_bytes(palette, 6, 0xE3, 0x77, 0xC2)
    _assert_palette_bytes(palette, 7, 0x7F, 0x7F, 0x7F)
    _assert_palette_bytes(palette, 8, 0xBC, 0xBD, 0x22)
    _assert_palette_bytes(palette, 9, 0x17, 0xBE, 0xCF)

    with assert_raises(contains="palette index must be within [0, 10); got 10"):
        _ = palette[10]
    with assert_raises(contains="palette index must be within [0, 10); got -1"):
        _ = palette[-1]


def test_cycle_uses_euclidean_wraparound() raises:
    var palette = Palette.category10()
    assert_true(palette.cycle(10) == palette[0])
    assert_true(palette.cycle(13) == palette[3])
    assert_true(palette.cycle(-1) == palette[9])


def test_curated_palette_endpoints_and_equality() raises:
    var category = Palette.category10()
    var tableau = Palette.tableau10()
    _assert_palette_bytes(category, 0, 0x1F, 0x77, 0xB4)
    _assert_palette_bytes(category, 9, 0x17, 0xBE, 0xCF)
    _assert_palette_bytes(tableau, 0, 0x4E, 0x79, 0xA7)
    _assert_palette_bytes(tableau, 1, 0xF2, 0x8E, 0x2C)
    _assert_palette_bytes(tableau, 2, 0xE1, 0x57, 0x59)
    _assert_palette_bytes(tableau, 3, 0x76, 0xB7, 0xB2)
    _assert_palette_bytes(tableau, 4, 0x59, 0xA1, 0x4F)
    _assert_palette_bytes(tableau, 5, 0xED, 0xC9, 0x48)
    _assert_palette_bytes(tableau, 6, 0xB0, 0x7A, 0xA1)
    _assert_palette_bytes(tableau, 7, 0xFF, 0x9D, 0xA7)
    _assert_palette_bytes(tableau, 8, 0x9C, 0x75, 0x5F)
    _assert_palette_bytes(tableau, 9, 0xBA, 0xB0, 0xAB)
    assert_true(category != tableau)
    assert_true(category == category.copy())
    assert_true(String(category) == "Palette(10 colors)")


def test_hex_output_uses_strict_lowercase_quantization() raises:
    var published = RGBA.from_stored_bytes(UInt8(0x1F), UInt8(0x77), UInt8(0xB4))
    assert_true(published.hex() == "#1f77b4ff")
    assert_true(RGBA.TRANSPARENT.hex() == "#00000000")
    assert_true(Srgb(1.0, 0.0, 0.0).hex() == "#ff0000")

    # The strict half-step policy rounds 0.5 * 255 = 127.5 upward to byte 128.
    assert_true(Srgb(0.5, 0.5, 0.5).hex() == "#808080")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
