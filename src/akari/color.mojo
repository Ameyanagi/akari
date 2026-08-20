"""Normalized numeric RGBA colors and interpolation."""

from std.builtin.comparable import Equatable
from std.io import Writable, Writer


def _validate_channel(value: Float64, name: String) raises:
    if value != value or value < 0.0 or value > 1.0:
        raise Error(name + " must be finite and between zero and one")


struct _Validated:
    def __init__(out self):
        pass


struct RGBA(Copyable, Equatable, Writable):
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

    @staticmethod
    def black() -> Self:
        return Self._from_validated(0.0, 0.0, 0.0, 1.0)

    @staticmethod
    def transparent() -> Self:
        return Self._from_validated(0.0, 0.0, 0.0, 0.0)

    @staticmethod
    def white() -> Self:
        return Self._from_validated(1.0, 1.0, 1.0, 1.0)

    @staticmethod
    def red_color() -> Self:
        return Self._from_validated(1.0, 0.0, 0.0, 1.0)

    @staticmethod
    def green_color() -> Self:
        return Self._from_validated(0.0, 1.0, 0.0, 1.0)

    @staticmethod
    def blue_color() -> Self:
        return Self._from_validated(0.0, 0.0, 1.0, 1.0)

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
