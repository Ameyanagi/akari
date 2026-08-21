"""Typed interpolation-space choices."""

from std.builtin.comparable import Equatable


struct MixSpace(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal choice of color interpolation space.

    Which space do I mix in? Use ``STORED`` for fidelity to stored numeric
    components and ``RGBA.lerp`` semantics, ``LINEAR`` for physical light mixing,
    and ``OKLAB`` for perceptually even ramps.
    """

    var _value: Int

    comptime STORED = MixSpace(_value=0)
    comptime LINEAR = MixSpace(_value=1)
    comptime OKLAB = MixSpace(_value=2)

    def __init__(out self, *, _value: Int):
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value
