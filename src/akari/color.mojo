"""Normalized numeric RGBA colors and interpolation."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer
from std.memory import bitcast

from .mix_space import MixSpace
from .oklab import Oklab
from .rgb_spaces import LinearSrgb, Srgb


comptime _FLOAT64_FRACTION_MASK = UInt64(0x000F_FFFF_FFFF_FFFF)
comptime _FLOAT64_EXPONENT_MASK = UInt64(0x7FF)
comptime _FLOAT64_HIDDEN_BIT = UInt64(0x0010_0000_0000_0000)
comptime _HEX_DIGITS = "0123456789abcdef"


def _validate_channel(value: Float64, name: String) raises:
    if value != value or value < 0.0 or value > 1.0:
        raise Error(name + " must be finite and within [0, 1]; got " + String(value))


def _validate_color_channel(value: Float64, name: String) raises:
    """Validate a color component and point byte-scale inputs to the importer."""
    if value != value or value < 0.0 or value > 1.0:
        var message = name + " must be finite and within [0, 1]; got " + String(value)
        if (
            value == value
            and value > 1.0
            and value <= 255.0
            and value == Float64(Int(value))
        ):
            message += "; for 0-255 byte components use from_stored_bytes"
        raise Error(message)


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


def _hex_digit_value(byte: UInt8) -> Int:
    """Return an ASCII hexadecimal digit's value, or -1 when invalid."""
    var value = Int(byte)
    if value >= 0x30 and value <= 0x39:
        return value - 0x30
    if value >= 0x61 and value <= 0x66:
        return value - 0x61 + 10
    if value >= 0x41 and value <= 0x46:
        return value - 0x41 + 10
    return -1


def _invalid_hex_message(text: String) -> String:
    return String(
        'hex color must be #rgb, #rrggbb, or #rrggbbaa; got "',
        text,
        '"',
    )


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
        _validate_color_channel(red, "red")
        _validate_color_channel(green, "green")
        _validate_color_channel(blue, "blue")
        _validate_color_channel(alpha, "alpha")
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

    @staticmethod
    def from_hex(text: String) raises -> RGBA:
        """Import ``#rgb``, ``#rrggbb``, or ``#rrggbbaa`` stored-space bytes.

        CSS shorthand expands each digit to a repeated byte. Any other shape or
        non-hexadecimal byte is rejected.
        """
        var length = text.byte_length()
        if length != 4 and length != 7 and length != 9:
            raise Error(_invalid_hex_message(text))

        var red = 0
        var green = 0
        var blue = 0
        var alpha = 255
        var byte_index = 0
        for byte in text.bytes():
            if byte_index == 0:
                if byte != UInt8(0x23):
                    raise Error(_invalid_hex_message(text))
            else:
                var digit = _hex_digit_value(byte)
                if digit < 0:
                    raise Error(_invalid_hex_message(text))
                if length == 4:
                    if byte_index == 1:
                        red = digit * 17
                    elif byte_index == 2:
                        green = digit * 17
                    else:
                        blue = digit * 17
                elif byte_index == 1:
                    red = digit * 16
                elif byte_index == 2:
                    red += digit
                elif byte_index == 3:
                    green = digit * 16
                elif byte_index == 4:
                    green += digit
                elif byte_index == 5:
                    blue = digit * 16
                elif byte_index == 6:
                    blue += digit
                elif byte_index == 7:
                    alpha = digit * 16
                else:
                    alpha += digit
            byte_index += 1

        return Self._from_validated(
            _normalized_from_byte(UInt8(red)),
            _normalized_from_byte(UInt8(green)),
            _normalized_from_byte(UInt8(blue)),
            _normalized_from_byte(UInt8(alpha)),
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
        _validate_color_channel(self._red, "red")
        _validate_color_channel(self._green, "green")
        _validate_color_channel(self._blue, "blue")
        _validate_color_channel(self._alpha, "alpha")

    def red(self) -> Float64:
        return self._red

    def green(self) -> Float64:
        return self._green

    def blue(self) -> Float64:
        return self._blue

    def alpha(self) -> Float64:
        return self._alpha

    def to_srgb(self) -> Srgb:
        """Reinterpret stored RGB as gamma-encoded sRGB and drop alpha.

        This is non-raising because construction already validated the stored
        components.
        """
        return Srgb._from_validated(self._red, self._green, self._blue)

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

    def hex_rgb(self) -> String:
        """Return CSS-style ``#rrggbb`` with strict stored-space quantization.

        Alpha is not emitted; use ``hex()`` when alpha matters.
        """
        var result = String("#")
        var stored = self.stored_bytes()
        for index in range(3):
            _append_hex_byte(result, stored[index])
        return result^

    def lerp(self, other: Self, amount: Float64) raises -> Self:
        """Interpolate components, rejecting an amount outside ``[0, 1]``.

        This is equivalent to ``mix(other, amount, MixSpace.STORED)``.
        """
        _validate_channel(amount, "interpolation amount")
        var remaining = 1.0 - amount
        return Self._from_validated(
            self._red * remaining + other._red * amount,
            self._green * remaining + other._green * amount,
            self._blue * remaining + other._blue * amount,
            self._alpha * remaining + other._alpha * amount,
        )

    def mix(
        self,
        other: Self,
        amount: Float64,
        space: MixSpace = MixSpace.STORED,
    ) raises -> Self:
        """Mix in the chosen space, rejecting an amount outside ``[0, 1]``."""
        _validate_channel(amount, "interpolation amount")
        return _mix_rgba(self, other, amount, space)

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


def _mix_rgba(a: RGBA, b: RGBA, fraction: Float64, space: MixSpace) -> RGBA:
    """Mix trusted RGBA values using the selected color-space semantics."""
    var remaining = 1.0 - fraction
    var alpha = a.alpha() * remaining + b.alpha() * fraction
    if space == MixSpace.STORED:
        return RGBA._from_validated(
            a.red() * remaining + b.red() * fraction,
            a.green() * remaining + b.green() * fraction,
            a.blue() * remaining + b.blue() * fraction,
            alpha,
        )

    var encoded_a = Srgb._from_validated(a.red(), a.green(), a.blue())
    var encoded_b = Srgb._from_validated(b.red(), b.green(), b.blue())
    var linear_a = encoded_a.to_linear()
    var linear_b = encoded_b.to_linear()
    if space == MixSpace.LINEAR:
        var mixed_linear = LinearSrgb._from_validated(
            linear_a.red() * remaining + linear_b.red() * fraction,
            linear_a.green() * remaining + linear_b.green() * fraction,
            linear_a.blue() * remaining + linear_b.blue() * fraction,
        )
        var mixed_encoded = mixed_linear.to_encoded()
        return RGBA._from_validated(
            mixed_encoded.red(),
            mixed_encoded.green(),
            mixed_encoded.blue(),
            alpha,
        )

    var oklab_a = linear_a.to_oklab()
    var oklab_b = linear_b.to_oklab()
    var mixed_oklab = Oklab._from_validated(
        oklab_a.lightness() * remaining + oklab_b.lightness() * fraction,
        oklab_a.a() * remaining + oklab_b.a() * fraction,
        oklab_a.b() * remaining + oklab_b.b() * fraction,
    )
    var mixed_encoded = mixed_oklab.to_linear_srgb().to_encoded()
    return RGBA._from_validated(
        mixed_encoded.red(),
        mixed_encoded.green(),
        mixed_encoded.blue(),
        alpha,
    )
