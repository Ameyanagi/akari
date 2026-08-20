"""Normalized numeric RGBA colors and interpolation."""


def _validate_channel(value: Float64, name: String) raises:
    if value != value or value < 0.0 or value > 1.0:
        raise Error(name + " must be finite and between zero and one")


struct RGBA(Copyable):
    """Constructor-validated RGBA components in ``[0, 1]``.

    Components are stored without an implied transfer function. ``lerp`` operates
    directly in this stored numeric space; later color-space types will make
    perceptual or transfer-aware interpolation explicit. Mojo 1.0 struct storage
    is externally mutable, so every public observation and operation revalidates
    the current components before returning a semantic result.
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
    def black() raises -> Self:
        return Self(0.0, 0.0, 0.0, 1.0)

    @staticmethod
    def transparent() raises -> Self:
        return Self(0.0, 0.0, 0.0, 0.0)

    def _validate(self) raises:
        _validate_channel(self._red, "red")
        _validate_channel(self._green, "green")
        _validate_channel(self._blue, "blue")
        _validate_channel(self._alpha, "alpha")

    def red(self) raises -> Float64:
        self._validate()
        return self._red

    def green(self) raises -> Float64:
        self._validate()
        return self._green

    def blue(self) raises -> Float64:
        self._validate()
        return self._blue

    def alpha(self) raises -> Float64:
        self._validate()
        return self._alpha

    def lerp(self, other: Self, amount: Float64) raises -> Self:
        """Interpolate components, rejecting an amount outside ``[0, 1]``."""
        self._validate()
        other._validate()
        _validate_channel(amount, "interpolation amount")
        var remaining = 1.0 - amount
        return Self(
            self._red * remaining + other._red * amount,
            self._green * remaining + other._green * amount,
            self._blue * remaining + other._blue * amount,
            self._alpha * remaining + other._alpha * amount,
        )

    def equals(self, other: Self) raises -> Bool:
        """Return exact component equality for deterministic values."""
        self._validate()
        other._validate()
        return (
            self._red == other._red
            and self._green == other._green
            and self._blue == other._blue
            and self._alpha == other._alpha
        )
