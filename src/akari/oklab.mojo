"""Perceptually uniform Oklab colors and linear-sRGB conversion."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer

from .color import _Validated, _validate_channel
from .rgb_spaces import LinearSrgb


def _validate_finite(value: Float64, name: String) raises:
    if value != value or value == Float64("inf") or value == Float64("-inf"):
        raise Error(name + " must be finite; got " + String(value))


def _clip_srgb_gamut(value: Float64) -> Float64:
    """Clip an Oklab conversion component deliberately into the sRGB gamut."""
    if value < 0.0:
        return 0.0
    if value > 1.0:
        return 1.0
    return value


struct Oklab(Copyable, Equatable, ImplicitlyCopyable, Writable):
    """Constructor-validated Oklab components.

    Lightness is finite and in ``[0, 1]``; opponent components ``a`` and ``b``
    are finite but intentionally unbounded. Construction establishes these
    invariants and public operations trust them thereafter. Direct mutation of
    underscore-prefixed storage is out of contract; call ``validate`` explicitly
    after unusual low-level mutation when a checkpoint is needed.
    """

    var _lightness: Float64
    var _a: Float64
    var _b: Float64

    def __init__(out self, lightness: Float64, a: Float64, b: Float64) raises:
        _validate_channel(lightness, "lightness")
        _validate_finite(a, "a")
        _validate_finite(b, "b")
        self._lightness = lightness
        self._a = a
        self._b = b

    @staticmethod
    def _from_validated(lightness: Float64, a: Float64, b: Float64) -> Self:
        """Construct from trusted conversion or interpolation results."""
        return Self(lightness, a, b, _validated=_Validated())

    def __init__(
        out self,
        lightness: Float64,
        a: Float64,
        b: Float64,
        *,
        _validated: _Validated,
    ):
        self._lightness = lightness
        self._a = a
        self._b = b

    def validate(self) raises:
        """Validate all stored components explicitly."""
        _validate_channel(self._lightness, "lightness")
        _validate_finite(self._a, "a")
        _validate_finite(self._b, "b")

    def lightness(self) -> Float64:
        return self._lightness

    def a(self) -> Float64:
        return self._a

    def b(self) -> Float64:
        return self._b

    def lighten(self, amount: Float64) raises -> Oklab:
        """Move lightness fractionally toward 1 while preserving ``a`` and ``b``."""
        _validate_channel(amount, "lighten amount")
        return Self._from_validated(
            self._lightness + (1.0 - self._lightness) * amount,
            self._a,
            self._b,
        )

    def darken(self, amount: Float64) raises -> Oklab:
        """Move lightness fractionally toward 0 while preserving ``a`` and ``b``."""
        _validate_channel(amount, "darken amount")
        return Self._from_validated(
            self._lightness * (1.0 - amount),
            self._a,
            self._b,
        )

    def lerp(self, other: Self, amount: Float64) raises -> Self:
        """Interpolate components, rejecting an amount outside ``[0, 1]``."""
        _validate_channel(amount, "interpolation amount")
        var remaining = 1.0 - amount
        return Self._from_validated(
            self._lightness * remaining + other._lightness * amount,
            self._a * remaining + other._a * amount,
            self._b * remaining + other._b * amount,
        )

    def to_linear_srgb(self) -> LinearSrgb:
        """Convert to linear sRGB with deliberate ``[0, 1]`` gamut clipping.

        Oklab includes colors outside the sRGB gamut, so this clips any converted
        channel outside ``[0, 1]``. This is semantic gamut clipping, unlike the
        rounding-dust-only clamp used by in-gamut RGB conversions.
        """
        var l_root = self._lightness + 0.3963377774 * self._a + 0.2158037573 * self._b
        var m_root = self._lightness - 0.1055613458 * self._a - 0.0638541728 * self._b
        var s_root = self._lightness - 0.0894841775 * self._a - 1.2914855480 * self._b
        var l = l_root * l_root * l_root
        var m = m_root * m_root * m_root
        var s = s_root * s_root * s_root
        return LinearSrgb._from_validated(
            _clip_srgb_gamut(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            _clip_srgb_gamut(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            _clip_srgb_gamut(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._lightness == other._lightness
            and self._a == other._a
            and self._b == other._b
        )

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Oklab(",
            self._lightness,
            ", ",
            self._a,
            ", ",
            self._b,
            ")",
        )
