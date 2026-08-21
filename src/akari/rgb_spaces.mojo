"""Nominal encoded, linear-light, HSL, and HSV color spaces."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer
from std.math import cbrt

from .color import (
    RGBA,
    _Validated,
    _append_hex_byte,
    _byte_from_normalized,
    _validate_channel,
    _validate_color_channel,
)
from .oklab import Oklab


# Standard IEC 61966-2-1 sRGB transfer constants.
comptime _SRGB_ENCODED_BREAKPOINT = 0.04045
comptime _SRGB_LINEAR_BREAKPOINT = 0.0031308
comptime _SRGB_TRANSFER_SLOPE = 12.92
comptime _SRGB_TRANSFER_OFFSET = 0.055
comptime _SRGB_TRANSFER_SCALE = 1.055
comptime _SRGB_TRANSFER_EXPONENT = 2.4


def _normalize_hue(hue: Float64) raises -> Float64:
    if hue != hue or hue == Float64("inf") or hue == Float64("-inf"):
        raise Error("hue must be finite; got " + String(hue))
    var normalized = hue % 360.0
    if normalized < 0.0:
        normalized += 360.0
    if normalized == 0.0:
        return 0.0
    return normalized


def _validate_normalized_hue(hue: Float64) raises:
    if hue != hue or hue < 0.0 or hue >= 360.0:
        raise Error(
            "hue must be finite and normalized within [0, 360); got " + String(hue)
        )


def _clamp_conversion_unit(value: Float64) -> Float64:
    # This only absorbs rounding dust, never out-of-gamut conversion math.
    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


def _absolute(value: Float64) -> Float64:
    if value < 0.0:
        return -value
    return value


def _maximum_channel(red: Float64, green: Float64, blue: Float64) -> Float64:
    var result = red
    if green > result:
        result = green
    if blue > result:
        result = blue
    return result


def _minimum_channel(red: Float64, green: Float64, blue: Float64) -> Float64:
    var result = red
    if green < result:
        result = green
    if blue < result:
        result = blue
    return result


def _rgb_hue(
    red: Float64,
    green: Float64,
    blue: Float64,
    maximum: Float64,
    delta: Float64,
) -> Float64:
    if delta == 0.0:
        return 0.0

    var hue: Float64
    if maximum == red:
        hue = 60.0 * ((green - blue) / delta)
        if hue < 0.0:
            hue += 360.0
    elif maximum == green:
        hue = 60.0 * ((blue - red) / delta + 2.0)
    else:
        hue = 60.0 * ((red - green) / delta + 4.0)

    if hue >= 360.0:
        return hue - 360.0
    return hue


def _hue_chroma_components(
    hue: Float64, chroma: Float64
) -> Tuple[Float64, Float64, Float64]:
    var hue_sector = hue / 60.0
    var second = chroma * (1.0 - _absolute(hue_sector % 2.0 - 1.0))
    if hue_sector < 1.0:
        return (chroma, second, 0.0)
    if hue_sector < 2.0:
        return (second, chroma, 0.0)
    if hue_sector < 3.0:
        return (0.0, chroma, second)
    if hue_sector < 4.0:
        return (0.0, second, chroma)
    if hue_sector < 5.0:
        return (second, 0.0, chroma)
    return (chroma, 0.0, second)


struct Srgb(Copyable, Equatable, Writable):
    """Gamma-encoded sRGB components in ``[0, 1]``.

    This is nominally distinct from both transfer-function-agnostic ``RGBA``
    and linear-light ``LinearSrgb``. Construction establishes the component
    invariants and public operations trust them thereafter. Direct mutation of
    underscore-prefixed storage is out of contract; call ``validate`` explicitly
    after unusual low-level mutation when a checkpoint is needed.
    """

    var _red: Float64
    var _green: Float64
    var _blue: Float64

    def __init__(out self, red: Float64, green: Float64, blue: Float64) raises:
        _validate_color_channel(red, "red")
        _validate_color_channel(green, "green")
        _validate_color_channel(blue, "blue")
        self._red = red
        self._green = green
        self._blue = blue

    @staticmethod
    def _from_validated(red: Float64, green: Float64, blue: Float64) -> Self:
        return Self(red, green, blue, _validated=_Validated())

    def __init__(
        out self,
        red: Float64,
        green: Float64,
        blue: Float64,
        *,
        _validated: _Validated,
    ):
        self._red = red
        self._green = green
        self._blue = blue

    def validate(self) raises:
        """Validate all stored components explicitly."""
        _validate_color_channel(self._red, "red")
        _validate_color_channel(self._green, "green")
        _validate_color_channel(self._blue, "blue")

    def red(self) -> Float64:
        return self._red

    def green(self) -> Float64:
        return self._green

    def blue(self) -> Float64:
        return self._blue

    def hex(self) -> String:
        """Return lowercase ``#rrggbb`` through strict byte quantization."""
        var result = String("#")
        _append_hex_byte(result, _byte_from_normalized(self._red))
        _append_hex_byte(result, _byte_from_normalized(self._green))
        _append_hex_byte(result, _byte_from_normalized(self._blue))
        return result^

    def to_rgba(self, alpha: Float64 = 1.0) raises -> RGBA:
        """Bridge gamma-encoded sRGB into RGBA, validating only alpha."""
        _validate_color_channel(alpha, "alpha")
        return RGBA._from_validated(self._red, self._green, self._blue, alpha)

    def to_linear(self) -> LinearSrgb:
        """Decode gamma-encoded components into linear-light sRGB."""
        return LinearSrgb._from_validated(
            _clamp_conversion_unit(_decode_srgb_channel(self._red)),
            _clamp_conversion_unit(_decode_srgb_channel(self._green)),
            _clamp_conversion_unit(_decode_srgb_channel(self._blue)),
        )

    def to_hsl(self) -> Hsl:
        """Convert to HSL, using zero hue and saturation for grays."""
        var maximum = _maximum_channel(self._red, self._green, self._blue)
        var minimum = _minimum_channel(self._red, self._green, self._blue)
        var delta = maximum - minimum
        var lightness = (maximum + minimum) / 2.0
        if delta == 0.0:
            return Hsl._from_validated(0.0, 0.0, _clamp_conversion_unit(lightness))

        var denominator = maximum + minimum
        if lightness > 0.5:
            denominator = 2.0 - maximum - minimum
        var saturation = delta / denominator
        return Hsl._from_validated(
            _rgb_hue(self._red, self._green, self._blue, maximum, delta),
            _clamp_conversion_unit(saturation),
            _clamp_conversion_unit(lightness),
        )

    def to_hsv(self) -> Hsv:
        """Convert to HSV, using zero hue and saturation for grays."""
        var maximum = _maximum_channel(self._red, self._green, self._blue)
        var minimum = _minimum_channel(self._red, self._green, self._blue)
        var delta = maximum - minimum
        if delta == 0.0:
            return Hsv._from_validated(0.0, 0.0, _clamp_conversion_unit(maximum))

        var saturation = delta / maximum
        return Hsv._from_validated(
            _rgb_hue(self._red, self._green, self._blue, maximum, delta),
            _clamp_conversion_unit(saturation),
            _clamp_conversion_unit(maximum),
        )

    def lighten(self, amount: Float64) raises -> Srgb:
        """Lighten through Oklab."""
        return self.to_linear().to_oklab().lighten(amount).to_linear_srgb().to_encoded()

    def darken(self, amount: Float64) raises -> Srgb:
        """Darken through Oklab."""
        return self.to_linear().to_oklab().darken(amount).to_linear_srgb().to_encoded()

    def saturate(self, amount: Float64) raises -> Srgb:
        """Saturate through HSL."""
        return self.to_hsl().saturate(amount).to_srgb()

    def desaturate(self, amount: Float64) raises -> Srgb:
        """Desaturate through HSL."""
        return self.to_hsl().desaturate(amount).to_srgb()

    def shift_hue(self, degrees: Float64) raises -> Srgb:
        """Shift hue through HSL."""
        return self.to_hsl().shift_hue(degrees).to_srgb()

    def __eq__(self, other: Self) -> Bool:
        return (
            self._red == other._red
            and self._green == other._green
            and self._blue == other._blue
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Srgb(", self._red, ", ", self._green, ", ", self._blue, ")")


struct LinearSrgb(Copyable, Equatable, Writable):
    """Linear-light sRGB components in ``[0, 1]``.

    Construction establishes the component invariants and public operations trust
    them thereafter. Direct mutation of underscore-prefixed storage is out of
    contract; call ``validate`` explicitly after unusual low-level mutation when
    a checkpoint is needed.
    """

    var _red: Float64
    var _green: Float64
    var _blue: Float64

    def __init__(out self, red: Float64, green: Float64, blue: Float64) raises:
        _validate_color_channel(red, "red")
        _validate_color_channel(green, "green")
        _validate_color_channel(blue, "blue")
        self._red = red
        self._green = green
        self._blue = blue

    @staticmethod
    def _from_validated(red: Float64, green: Float64, blue: Float64) -> Self:
        return Self(red, green, blue, _validated=_Validated())

    def __init__(
        out self,
        red: Float64,
        green: Float64,
        blue: Float64,
        *,
        _validated: _Validated,
    ):
        self._red = red
        self._green = green
        self._blue = blue

    def validate(self) raises:
        """Validate all stored components explicitly."""
        _validate_color_channel(self._red, "red")
        _validate_color_channel(self._green, "green")
        _validate_color_channel(self._blue, "blue")

    def red(self) -> Float64:
        return self._red

    def green(self) -> Float64:
        return self._green

    def blue(self) -> Float64:
        return self._blue

    def to_encoded(self) -> Srgb:
        """Encode linear-light components using the sRGB transfer function."""
        return Srgb._from_validated(
            _clamp_conversion_unit(_encode_srgb_channel(self._red)),
            _clamp_conversion_unit(_encode_srgb_channel(self._green)),
            _clamp_conversion_unit(_encode_srgb_channel(self._blue)),
        )

    def to_oklab(self) -> Oklab:
        """Convert trusted linear-light sRGB components to Oklab.

        The Oklab lightness is clamped only to absorb matrix rounding dust;
        opponent components are preserved without clamping.
        """
        var l = (
            0.4122214708 * self._red
            + 0.5363325363 * self._green
            + 0.0514459929 * self._blue
        )
        var m = (
            0.2119034982 * self._red
            + 0.6806995451 * self._green
            + 0.1073969566 * self._blue
        )
        var s = (
            0.0883024619 * self._red
            + 0.2817188376 * self._green
            + 0.6299787005 * self._blue
        )
        var l_root = cbrt(l)
        var m_root = cbrt(m)
        var s_root = cbrt(s)
        return Oklab._from_validated(
            _clamp_conversion_unit(
                0.2104542553 * l_root + 0.7936177850 * m_root - 0.0040720468 * s_root
            ),
            1.9779984951 * l_root - 2.4285922050 * m_root + 0.4505937099 * s_root,
            0.0259040371 * l_root + 0.7827717662 * m_root - 0.8086757660 * s_root,
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._red == other._red
            and self._green == other._green
            and self._blue == other._blue
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "LinearSrgb(",
            self._red,
            ", ",
            self._green,
            ", ",
            self._blue,
            ")",
        )


struct Hsl(Copyable, Equatable, Writable):
    """HSL with hue in degrees and other components in ``[0, 1]``.

    Any finite constructor hue is reduced exactly around the circle into
    ``[0, 360)``. When saturation is zero, ``to_srgb`` returns the gray of the
    stored lightness and ignores hue. Construction establishes the invariants and
    public operations trust them thereafter. Direct mutation of underscore-
    prefixed storage is out of contract; call ``validate`` explicitly after
    unusual low-level mutation when a checkpoint is needed.
    """

    var _hue: Float64
    var _saturation: Float64
    var _lightness: Float64

    def __init__(
        out self, hue: Float64, saturation: Float64, lightness: Float64
    ) raises:
        var normalized_hue = _normalize_hue(hue)
        _validate_channel(saturation, "saturation")
        _validate_channel(lightness, "lightness")
        self._hue = normalized_hue
        self._saturation = saturation
        self._lightness = lightness

    @staticmethod
    def _from_validated(hue: Float64, saturation: Float64, lightness: Float64) -> Self:
        return Self(hue, saturation, lightness, _validated=_Validated())

    def __init__(
        out self,
        hue: Float64,
        saturation: Float64,
        lightness: Float64,
        *,
        _validated: _Validated,
    ):
        self._hue = hue
        self._saturation = saturation
        self._lightness = lightness

    def validate(self) raises:
        """Validate the canonical hue and normalized components explicitly."""
        _validate_normalized_hue(self._hue)
        _validate_channel(self._saturation, "saturation")
        _validate_channel(self._lightness, "lightness")

    def hue(self) -> Float64:
        return self._hue

    def saturation(self) -> Float64:
        return self._saturation

    def lightness(self) -> Float64:
        return self._lightness

    def shift_hue(self, degrees: Float64) raises -> Hsl:
        """Shift hue by finite degrees and wrap the result into ``[0, 360)``."""
        if (
            degrees != degrees
            or degrees == Float64("inf")
            or degrees == Float64("-inf")
        ):
            raise Error("hue shift must be finite; got " + String(degrees))
        return Self._from_validated(
            _normalize_hue(self._hue + degrees),
            self._saturation,
            self._lightness,
        )

    def saturate(self, amount: Float64) raises -> Hsl:
        """Move fractionally toward full saturation; 0 is identity and 1 is full."""
        _validate_channel(amount, "saturate amount")
        return Self._from_validated(
            self._hue,
            self._saturation + (1.0 - self._saturation) * amount,
            self._lightness,
        )

    def desaturate(self, amount: Float64) raises -> Hsl:
        """Move fractionally toward gray; 0 is identity and 1 is gray."""
        _validate_channel(amount, "desaturate amount")
        return Self._from_validated(
            self._hue,
            self._saturation * (1.0 - amount),
            self._lightness,
        )

    def to_srgb(self) -> Srgb:
        """Convert to gamma-encoded sRGB; achromatic values become gray."""
        if self._saturation == 0.0:
            var gray = _clamp_conversion_unit(self._lightness)
            return Srgb._from_validated(gray, gray, gray)

        var chroma = (1.0 - _absolute(2.0 * self._lightness - 1.0)) * self._saturation
        var components = _hue_chroma_components(self._hue, chroma)
        var offset = self._lightness - chroma / 2.0
        return Srgb._from_validated(
            _clamp_conversion_unit(components[0] + offset),
            _clamp_conversion_unit(components[1] + offset),
            _clamp_conversion_unit(components[2] + offset),
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._hue == other._hue
            and self._saturation == other._saturation
            and self._lightness == other._lightness
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Hsl(",
            self._hue,
            ", ",
            self._saturation,
            ", ",
            self._lightness,
            ")",
        )


struct Hsv(Copyable, Equatable, Writable):
    """HSV with hue in degrees and other components in ``[0, 1]``.

    Any finite constructor hue is reduced exactly around the circle into
    ``[0, 360)``. When saturation is zero, ``to_srgb`` returns the gray of the
    stored value and ignores hue. Construction establishes the invariants and
    public operations trust them thereafter. Direct mutation of underscore-
    prefixed storage is out of contract; call ``validate`` explicitly after
    unusual low-level mutation when a checkpoint is needed.
    """

    var _hue: Float64
    var _saturation: Float64
    var _value: Float64

    def __init__(out self, hue: Float64, saturation: Float64, value: Float64) raises:
        var normalized_hue = _normalize_hue(hue)
        _validate_channel(saturation, "saturation")
        _validate_channel(value, "value")
        self._hue = normalized_hue
        self._saturation = saturation
        self._value = value

    @staticmethod
    def _from_validated(hue: Float64, saturation: Float64, value: Float64) -> Self:
        return Self(hue, saturation, value, _validated=_Validated())

    def __init__(
        out self,
        hue: Float64,
        saturation: Float64,
        value: Float64,
        *,
        _validated: _Validated,
    ):
        self._hue = hue
        self._saturation = saturation
        self._value = value

    def validate(self) raises:
        """Validate the canonical hue and normalized components explicitly."""
        _validate_normalized_hue(self._hue)
        _validate_channel(self._saturation, "saturation")
        _validate_channel(self._value, "value")

    def hue(self) -> Float64:
        return self._hue

    def saturation(self) -> Float64:
        return self._saturation

    def value(self) -> Float64:
        return self._value

    def to_srgb(self) -> Srgb:
        """Convert to gamma-encoded sRGB; achromatic values become gray."""
        if self._saturation == 0.0:
            var gray = _clamp_conversion_unit(self._value)
            return Srgb._from_validated(gray, gray, gray)

        var chroma = self._value * self._saturation
        var components = _hue_chroma_components(self._hue, chroma)
        var offset = self._value - chroma
        return Srgb._from_validated(
            _clamp_conversion_unit(components[0] + offset),
            _clamp_conversion_unit(components[1] + offset),
            _clamp_conversion_unit(components[2] + offset),
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._hue == other._hue
            and self._saturation == other._saturation
            and self._value == other._value
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Hsv(",
            self._hue,
            ", ",
            self._saturation,
            ", ",
            self._value,
            ")",
        )


def _decode_srgb_channel(value: Float64) -> Float64:
    if value == 1.0:
        return 1.0
    if value <= _SRGB_ENCODED_BREAKPOINT:
        return value / _SRGB_TRANSFER_SLOPE
    return (
        (value + _SRGB_TRANSFER_OFFSET) / _SRGB_TRANSFER_SCALE
    ) ** _SRGB_TRANSFER_EXPONENT


def _encode_srgb_channel(value: Float64) -> Float64:
    if value == 1.0:
        return 1.0
    if value <= _SRGB_LINEAR_BREAKPOINT:
        return _SRGB_TRANSFER_SLOPE * value
    return (
        _SRGB_TRANSFER_SCALE * value ** (1.0 / _SRGB_TRANSFER_EXPONENT)
        - _SRGB_TRANSFER_OFFSET
    )
