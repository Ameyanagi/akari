"""Evenly spaced color gradients with explicit interpolation semantics."""

from std.builtin.comparable import Equatable
from std.collections import List
from std.io import Writable, Writer
from std.math import floor

from .color import RGBA, _mix_rgba
from .mix_space import MixSpace


def _clamp_gradient_coordinate(value: Float64) -> Float64:
    if value != value or value <= 0.0:
        return 0.0
    if value >= 1.0:
        return 1.0
    return value


def _mix_space_name(space: MixSpace) -> String:
    if space == MixSpace.STORED:
        return "stored"
    if space == MixSpace.LINEAR:
        return "linear"
    return "oklab"


struct Gradient(Copyable, Equatable, Writable):
    """An owned gradient whose stops are evenly spaced over ``[0, 1]``.

    ``STORED`` linearly mixes all four transfer-agnostic ``RGBA`` components.
    ``LINEAR`` interprets stored RGB as gamma-encoded sRGB, decodes it, mixes in
    linear light, and re-encodes it. ``OKLAB`` interprets stored RGB the same
    way, converts through linear sRGB to Oklab, mixes there, converts back with
    documented sRGB gamut clipping, and re-encodes it. Alpha always mixes in
    stored space. The sRGB interpretation is local to ``LINEAR`` and ``OKLAB``;
    ``RGBA`` itself remains transfer-agnostic.

    Segment selection computes ``x = t * (len(stops) - 1)``, uses ``floor(x)``
    and the remaining fractional part, and returns exact stops without a color-
    space round trip. Evaluation clamps into ``[0, 1]`` and maps NaN to 0.0.
    It is a pure function of stops, space, and ``t``: identical inputs produce
    bit-identical outputs.
    """

    var _stops: List[RGBA]
    var _space: MixSpace

    def __init__(
        out self,
        var stops: List[RGBA],
        space: MixSpace = MixSpace.OKLAB,
    ) raises:
        if len(stops) < 2:
            raise Error(String("gradient needs at least 2 stops; got ", len(stops)))
        self._stops = stops^
        self._space = space

    def space(self) -> MixSpace:
        return self._space

    def _mix(self, a: RGBA, b: RGBA, fraction: Float64) -> RGBA:
        return _mix_rgba(a, b, fraction, self._space)

    def at(self, t: Float64) -> RGBA:
        """Sample after clamping to ``[0, 1]``; NaN maps to the first stop."""
        var coordinate = _clamp_gradient_coordinate(t)
        if coordinate == 0.0:
            return self._stops[0]
        var final_index = len(self._stops) - 1
        if coordinate == 1.0:
            return self._stops[final_index]

        var position = coordinate * Float64(final_index)
        var index = Int(floor(position))
        var fraction = position - Float64(index)
        if fraction == 0.0:
            return self._stops[index]
        return self._mix(self._stops[index], self._stops[index + 1], fraction)

    def sample(self, i: Int, n: Int) raises -> RGBA:
        """Return endpoint-inclusive sample ``i`` of ``n``.

        Raises ``sample count must be positive; got <n>`` when ``n <= 0`` and
        ``sample index must be within [0, <n>); got <i>`` outside the index
        range. A count of one samples 0.0.
        """
        if n <= 0:
            raise Error(String("sample count must be positive; got ", n))
        if i < 0 or i >= n:
            raise Error(
                String(
                    "sample index must be within [0, ",
                    n,
                    "); got ",
                    i,
                )
            )
        if n == 1:
            return self.at(0.0)
        return self.at(Float64(i) / Float64(n - 1))

    def colors(self, n: Int) -> List[RGBA]:
        """Return evenly spaced endpoint-inclusive colors.

        Zero and negative counts return an empty list. A count of one returns
        only ``at(0.0)``.
        """
        if n <= 0:
            return List[RGBA]()

        var result = List[RGBA](capacity=n)
        for index in range(n):
            if n == 1:
                result.append(self.at(0.0))
            else:
                result.append(self.at(Float64(index) / Float64(n - 1)))
        return result^

    def __eq__(self, other: Self) -> Bool:
        if self._space != other._space or len(self._stops) != len(other._stops):
            return False
        for index in range(len(self._stops)):
            if self._stops[index] != other._stops[index]:
                return False
        return True

    def __str__(self) -> String:
        var result = String()
        self.write_to(result)
        return result^

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Gradient(",
            len(self._stops),
            " stops, ",
            _mix_space_name(self._space),
            ")",
        )
