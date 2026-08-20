"""Normalized numeric RGBA colors and interpolation."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer
from std.memory import bitcast


comptime _FLOAT64_FRACTION_MASK = UInt64(0x000F_FFFF_FFFF_FFFF)
comptime _FLOAT64_EXPONENT_MASK = UInt64(0x7FF)
comptime _FLOAT64_HIDDEN_BIT = UInt64(0x0010_0000_0000_0000)
comptime _HEX_DIGITS = "0123456789abcdef"


def _validate_channel(value: Float64, name: String) raises:
    if value != value or value < 0.0 or value > 1.0:
        raise Error(name + " must be finite and within [0, 1]; got " + String(value))


def _normalized_from_byte(value: UInt8) -> Float64:
    """Normalize one stored byte by correctly rounded binary64 division."""
    return Float64(value) / 255.0


def _uint64_bit_length(value: UInt64) -> Int:
    var cursor = value
    var length = 0
    while cursor != UInt64(0):
        cursor >>= 1
        length += 1
    return length


def _at_or_above_half_step(value: Float64, index: Int) -> Bool:
    """Compare a valid binary64 value with ``(2 * index + 1) / 510`` exactly."""
    var bits = bitcast[DType.uint64](value)
    var raw_exponent = Int((bits >> 52) & _FLOAT64_EXPONENT_MASK)
    var significand = bits & _FLOAT64_FRACTION_MASK
    var exponent = -1074
    if raw_exponent != 0:
        significand |= _FLOAT64_HIDDEN_BIT
        exponent = raw_exponent - 1075
    if significand == UInt64(0):
        return False

    # For a validated component, exponent is negative. Compare
    # 510 * significand with (2 * index + 1) * 2**(-exponent). Bit lengths
    # reject unequal magnitudes before the only shift, keeping it in UInt64.
    var scaled_significand = UInt64(510) * significand
    var numerator = UInt64(2 * index + 1)
    var shift = -exponent
    var left_length = _uint64_bit_length(scaled_significand)
    var right_length = _uint64_bit_length(numerator) + shift
    if left_length != right_length:
        return left_length > right_length
    return scaled_significand >= (numerator << UInt64(shift))


def _byte_from_normalized(value: Float64) -> UInt8:
    """Quantize one trusted normalized component by exact half-step search."""
    var lower = 0
    var upper = 255
    while lower < upper:
        var middle = lower + (upper - lower) // 2
        if _at_or_above_half_step(value, middle):
            lower = middle + 1
        else:
            upper = middle
    return UInt8(lower)


def _append_hex_byte(mut result: String, byte: UInt8):
    """Append one byte as two lowercase hexadecimal digits."""
    var value = Int(byte)
    var high = value // 16
    var low = value % 16
    result += String(_HEX_DIGITS[byte = high : high + 1])
    result += String(_HEX_DIGITS[byte = low : low + 1])


struct _Validated:
    def __init__(out self):
        pass


struct RGBA(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Constructor-validated RGBA components in ``[0, 1]``.

    Components are stored without an implied transfer function. ``lerp`` operates
    directly in this stored numeric space; later color-space types will make
    perceptual or transfer-aware interpolation explicit. Construction establishes
    the component invariants and public operations trust them thereafter. Direct
    mutation of underscore-prefixed storage is out of contract; call ``validate``
    explicitly after unusual low-level mutation when a checkpoint is needed.
    """

    var _red: Float64
    var _green: Float64
    var _blue: Float64
    var _alpha: Float64

    def __init__(
        out self,
        red: Float64,
        green: Float64,
        blue: Float64,
        alpha: Float64 = 1.0,
    ) raises:
        _validate_channel(red, "red")
        _validate_channel(green, "green")
        _validate_channel(blue, "blue")
        _validate_channel(alpha, "alpha")
        self._red = red
        self._green = green
        self._blue = blue
        self._alpha = alpha

    @staticmethod
    def _from_validated(
        red: Float64, green: Float64, blue: Float64, alpha: Float64
    ) -> Self:
        return Self(red, green, blue, alpha, _validated=_Validated())

    @staticmethod
    def from_stored_bytes(
        red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255
    ) -> Self:
        """Import bytes using stored-space quantization and no transfer function.

        Each byte normalizes as the correctly rounded ``value / 255`` and needs
        no validation. See ``docs/numeric-conversion.md`` for the numeric
        contract.
        """
        return Self._from_validated(
            _normalized_from_byte(red),
            _normalized_from_byte(green),
            _normalized_from_byte(blue),
            _normalized_from_byte(alpha),
        )

    def __init__(
        out self,
        red: Float64,
        green: Float64,
        blue: Float64,
        alpha: Float64,
        *,
        _validated: _Validated,
    ):
        self._red = red
        self._green = green
        self._blue = blue
        self._alpha = alpha

    comptime BLACK = RGBA(0.0, 0.0, 0.0, 1.0, _validated=_Validated())
    comptime WHITE = RGBA(1.0, 1.0, 1.0, 1.0, _validated=_Validated())
    comptime RED = RGBA(1.0, 0.0, 0.0, 1.0, _validated=_Validated())
    comptime GREEN = RGBA(0.0, 1.0, 0.0, 1.0, _validated=_Validated())
    comptime BLUE = RGBA(0.0, 0.0, 1.0, 1.0, _validated=_Validated())
    comptime TRANSPARENT = RGBA(0.0, 0.0, 0.0, 0.0, _validated=_Validated())

    def validate(self) raises:
        """Validate all stored components explicitly."""
        _validate_channel(self._red, "red")
        _validate_channel(self._green, "green")
        _validate_channel(self._blue, "blue")
        _validate_channel(self._alpha, "alpha")

    def red(self) -> Float64:
        return self._red

    def green(self) -> Float64:
        return self._green

    def blue(self) -> Float64:
        return self._blue

    def alpha(self) -> Float64:
        return self._alpha

    def stored_bytes(self) -> SIMD[DType.uint8, 4]:
        """Export bytes using stored-space quantization and no transfer function.

        Export trusts construction-established invariants and does not revalidate
        or clamp. Callers who mutated underscore-prefixed fields directly must call
        ``validate()`` before export. See ``docs/numeric-conversion.md`` for the
        numeric contract.
        """
        return SIMD[DType.uint8, 4](
            _byte_from_normalized(self._red),
            _byte_from_normalized(self._green),
            _byte_from_normalized(self._blue),
            _byte_from_normalized(self._alpha),
        )

    def hex(self) -> String:
        """Return ``#rrggbbaa`` using strict stored-space byte quantization.

        The RGB and alpha components carry no implied transfer function; this is
        the same transfer-agnostic stored-space export as ``stored_bytes``.
        """
        var result = String("#")
        var stored = self.stored_bytes()
        for index in range(4):
            _append_hex_byte(result, stored[index])
        return result^

    def lerp(self, other: Self, amount: Float64) raises -> Self:
        """Interpolate components, rejecting an amount outside ``[0, 1]``."""
        _validate_channel(amount, "interpolation amount")
        var remaining = 1.0 - amount
        return Self._from_validated(
            self._red * remaining + other._red * amount,
            self._green * remaining + other._green * amount,
            self._blue * remaining + other._blue * amount,
            self._alpha * remaining + other._alpha * amount,
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._red == other._red
            and self._green == other._green
            and self._blue == other._blue
            and self._alpha == other._alpha
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "RGBA(",
            self._red,
            ", ",
            self._green,
            ", ",
            self._blue,
            ", ",
            self._alpha,
            ")",
        )
