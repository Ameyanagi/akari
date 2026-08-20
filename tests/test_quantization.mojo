from akari import RGBA
from akari.color import _byte_from_normalized, _normalized_from_byte
from std.math import abs
from std.memory import bitcast
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


comptime _FLOAT64_FRACTION_MASK = UInt64(0x000F_FFFF_FFFF_FFFF)
comptime _FLOAT64_EXPONENT_MASK = UInt64(0x7FF)
comptime _FLOAT64_HIDDEN_BIT = UInt64(0x0010_0000_0000_0000)


def _oracle_is_below_half_step(value: Float64, index: Int) -> Bool:
    """Compare against the exact half step independently with Int256."""
    var bits = bitcast[DType.uint64](value)
    var raw_exponent = Int((bits >> 52) & _FLOAT64_EXPONENT_MASK)
    var significand = bits & _FLOAT64_FRACTION_MASK
    var exponent = -1074
    if raw_exponent != 0:
        significand |= _FLOAT64_HIDDEN_BIT
        exponent = raw_exponent - 1075

    var left = Int256(significand) * Int256(510)
    var right = Int256(2 * index + 1)
    if exponent < 0:
        right <<= Int256(-exponent)
    else:
        left <<= Int256(exponent)
    return left < right


def _oracle_threshold(index: Int) -> Float64:
    """Derive CEIL64((2 * index + 1) / 510) without implementation helpers."""
    var rounded = Float64(2 * index + 1) / 510.0
    if _oracle_is_below_half_step(rounded, index):
        var bits = bitcast[DType.uint64](rounded)
        return bitcast[DType.float64](bits + UInt64(1))
    return rounded


def _from_bits(bits: UInt64) -> Float64:
    return bitcast[DType.float64](bits)


def _assert_adjacency(
    index: Int, down_bits: UInt64, threshold_bits: UInt64, up_bits: UInt64
) raises:
    assert_equal(_byte_from_normalized(_from_bits(down_bits)), UInt8(index))
    assert_equal(_byte_from_normalized(_from_bits(threshold_bits)), UInt8(index + 1))
    assert_equal(_byte_from_normalized(_from_bits(up_bits)), UInt8(index + 1))


def _assert_abs_error_bound(value: Float64) raises:
    var recovered = _normalized_from_byte(_byte_from_normalized(value))
    assert_true(abs(value - recovered) <= 1.0 / 510.0)


def _assert_alpha_round_trip(value: UInt8) raises:
    var color = RGBA.from_stored_bytes(UInt8(0), UInt8(0), UInt8(0), value)
    assert_equal(color.alpha(), _normalized_from_byte(value))
    assert_equal(color.stored_bytes()[3], value)


def test_normative_fixtures() raises:
    assert_equal(_byte_from_normalized(0.0), UInt8(0))
    assert_equal(_byte_from_normalized(_normalized_from_byte(UInt8(1))), UInt8(1))
    assert_equal(_byte_from_normalized(_oracle_threshold(127)), UInt8(128))
    assert_equal(_byte_from_normalized(_oracle_threshold(126)), UInt8(127))
    assert_equal(_byte_from_normalized(_oracle_threshold(254)), UInt8(255))
    assert_equal(_byte_from_normalized(1.0), UInt8(255))


def test_normative_hex_adjacency_fixtures() raises:
    _assert_adjacency(
        0,
        UInt64(0x3F60_1010_1010_1010),
        UInt64(0x3F60_1010_1010_1011),
        UInt64(0x3F60_1010_1010_1012),
    )
    _assert_adjacency(
        126,
        UInt64(0x3FDF_BFBF_BFBF_BFBF),
        UInt64(0x3FDF_BFBF_BFBF_BFC0),
        UInt64(0x3FDF_BFBF_BFBF_BFC1),
    )
    _assert_adjacency(
        127,
        UInt64(0x3FDF_FFFF_FFFF_FFFF),
        UInt64(0x3FE0_0000_0000_0000),
        UInt64(0x3FE0_0000_0000_0001),
    )
    # Required regression: floor(x * 255 + 0.5) misquantizes this down value.
    _assert_adjacency(
        131,
        UInt64(0x3FE0_8080_8080_8080),
        UInt64(0x3FE0_8080_8080_8081),
        UInt64(0x3FE0_8080_8080_8082),
    )
    _assert_adjacency(
        254,
        UInt64(0x3FEF_EFEF_EFEF_EFEF),
        UInt64(0x3FEF_EFEF_EFEF_EFF0),
        UInt64(0x3FEF_EFEF_EFEF_EFF1),
    )


def test_all_bytes_round_trip_through_scalar_and_rgba_apis() raises:
    for index in range(256):
        var value = UInt8(index)
        assert_equal(_byte_from_normalized(_normalized_from_byte(value)), value)

        var color = RGBA.from_stored_bytes(value, value, value, value)
        var stored = color.stored_bytes()
        assert_equal(stored[0], value)
        assert_equal(stored[1], value)
        assert_equal(stored[2], value)
        assert_equal(stored[3], value)


def test_absolute_error_bound_on_grid_and_fixtures() raises:
    for index in range(1025):
        _assert_abs_error_bound(Float64(index) / 1024.0)

    _assert_abs_error_bound(0.0)
    _assert_abs_error_bound(_normalized_from_byte(UInt8(1)))
    _assert_abs_error_bound(_oracle_threshold(127))
    _assert_abs_error_bound(_oracle_threshold(126))
    _assert_abs_error_bound(_oracle_threshold(254))
    _assert_abs_error_bound(1.0)


def test_every_directed_threshold_and_adjacent_values() raises:
    for index in range(255):
        var threshold = _oracle_threshold(index)
        var threshold_bits = bitcast[DType.uint64](threshold)
        var down = _from_bits(threshold_bits - UInt64(1))
        var up = _from_bits(threshold_bits + UInt64(1))
        assert_equal(_byte_from_normalized(down), UInt8(index))
        assert_equal(_byte_from_normalized(threshold), UInt8(index + 1))
        assert_equal(_byte_from_normalized(up), UInt8(index + 1))


def test_validate_rejects_each_directly_mutated_component() raises:
    var invalid_red = RGBA(0.1, 0.2, 0.3, 0.4)
    invalid_red._red = Float64("nan")
    with assert_raises(contains="red must be finite"):
        invalid_red.validate()

    var invalid_green = RGBA(0.1, 0.2, 0.3, 0.4)
    invalid_green._green = Float64("inf")
    with assert_raises(contains="green must be finite"):
        invalid_green.validate()

    var invalid_blue = RGBA(0.1, 0.2, 0.3, 0.4)
    invalid_blue._blue = -1.0
    with assert_raises(contains="blue must be finite"):
        invalid_blue.validate()

    var invalid_alpha = RGBA(0.1, 0.2, 0.3, 0.4)
    invalid_alpha._alpha = 2.0
    with assert_raises(contains="alpha must be finite"):
        invalid_alpha.validate()

    # Export is intentionally not called on these invalid values: stored_bytes
    # trusts constructor-established invariants and does not revalidate.


def test_alpha_uses_identical_stored_space_quantization() raises:
    _assert_alpha_round_trip(UInt8(0))
    _assert_alpha_round_trip(UInt8(1))
    _assert_alpha_round_trip(UInt8(127))
    _assert_alpha_round_trip(UInt8(128))
    _assert_alpha_round_trip(UInt8(254))
    _assert_alpha_round_trip(UInt8(255))

    var opaque = RGBA.from_stored_bytes(UInt8(0), UInt8(0), UInt8(0))
    assert_equal(opaque.stored_bytes()[3], UInt8(255))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
