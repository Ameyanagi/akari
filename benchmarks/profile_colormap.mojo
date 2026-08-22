"""Long-running compiled workload for sampling colormap CPU hot paths."""

from akari import Colormap, RGBA
from std.benchmark import keep
from std.collections import List
from std.sys import argv


comptime _VALUE_COUNT = 1 << 20
comptime _ITERATIONS = 1536


def _values() raises -> List[Float64]:
    var values = List[Float64](capacity=_VALUE_COUNT)
    for index in range(_VALUE_COUNT):
        if index % 257 == 0:
            values.append(Float64("nan"))
        elif index % 251 == 0:
            values.append(Float64("inf"))
        elif index % 241 == 0:
            values.append(Float64("-inf"))
        else:
            values.append(Float64((index * 73) % 2048) / 1024.0 - 0.5)
    return values^


@no_inline
def _profile_colors() raises:
    var values = _values()
    var results = List[RGBA](length=len(values), fill=RGBA.BLACK)
    for _ in range(_ITERATIONS):
        Colormap.VIRIDIS.map_into(values, 0.0, 1.0, results)
    keep(results[len(results) - 1].green())


@no_inline
def _profile_bytes() raises:
    var values = _values()
    var results = List[SIMD[DType.uint8, 4]](
        length=len(values), fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    for _ in range(_ITERATIONS):
        Colormap.VIRIDIS.map_bytes_into(values, 0.0, 1.0, results)
    keep(results[len(results) - 1][1])


def main() raises:
    var arguments = argv()
    if len(arguments) == 2 and String(arguments[1]) == "colors":
        _profile_colors()
        return
    if len(arguments) == 2 and String(arguments[1]) == "bytes":
        _profile_bytes()
        return
    raise Error("usage: profile_colormap <colors|bytes>")
