"""Paired allocating-versus-reused endpoint-inclusive gradient sampling."""

from akari import Gradient, MixSpace, RGBA
from std.benchmark import keep
from std.collections import List
from std.testing import assert_equal, assert_true
from std.time import perf_counter_ns


comptime _SAMPLE_BUDGET = 131_072
comptime _MEASUREMENTS = 11


def _gradient(space: MixSpace) raises -> Gradient:
    var stops: List[RGBA] = [
        RGBA(0.1, 0.2, 0.8, 0.0),
        RGBA(0.8, 0.1, 0.3, 0.25),
        RGBA(0.3, 0.7, 0.2, 0.5),
        RGBA(0.4, 0.2, 0.9, 0.75),
        RGBA(0.9, 0.8, 0.1, 1.0),
    ]
    return Gradient(stops^, space)


def _allocating(gradient: Gradient, count: Int, iterations: Int) -> Float64:
    var checksum = 0.0
    for iteration in range(iterations):
        var colors = gradient.colors(count)
        var color = colors[(iteration * 13) % count]
        checksum += color.red() + color.green() + color.alpha()
        keep(colors)
    return checksum


def _reused(
    gradient: Gradient, results: Span[mut=True, RGBA, _], iterations: Int
) -> Float64:
    var checksum = 0.0
    for iteration in range(iterations):
        gradient.colors_into(results)
        var color = results[(iteration * 13) % len(results)]
        checksum += color.red() + color.green() + color.alpha()
        keep(results)
    return checksum


def _percentiles(mut values: List[Int]) -> Tuple[Int, Int]:
    for index in range(1, len(values)):
        var value = values[index]
        var cursor = index
        while cursor > 0 and values[cursor - 1] > value:
            values[cursor] = values[cursor - 1]
            cursor -= 1
        values[cursor] = value
    return (values[len(values) // 2], values[(len(values) * 95 + 99) // 100 - 1])


def _print(
    space: StringSlice,
    variant: StringSlice,
    count: Int,
    iterations: Int,
    mut elapsed: List[Int],
    checksum: Float64,
):
    var p50, p95 = _percentiles(elapsed)
    print(
        "space=", space, " variant=", variant, " count=", count,
        " iterations=", iterations, " p50_ns_per_color=",
        Float64(p50) / Float64(count * iterations), " p95_ns_per_color=",
        Float64(p95) / Float64(count * iterations), " checksum=", checksum, sep="",
    )


def _measure(space: MixSpace, name: StringSlice, count: Int) raises:
    var gradient = _gradient(space)
    var results = List[RGBA](length=count, fill=RGBA.BLACK)
    var reference = gradient.colors(count)
    gradient.colors_into(results)
    for index in range(count):
        assert_true(results[index] == reference[index])
        assert_true(results[index] == gradient.at(Float64(index) / Float64(count - 1)))
    var iterations = max(1, _SAMPLE_BUDGET // count)
    for _ in range(2):
        assert_equal(_allocating(gradient, count, iterations), _reused(gradient, results, iterations))
    var allocated_times = List[Int](capacity=_MEASUREMENTS)
    var reused_times = List[Int](capacity=_MEASUREMENTS)
    var checksum = 0.0
    for measurement in range(_MEASUREMENTS):
        var allocating_checksum = 0.0
        var reused_checksum = 0.0
        # Alternate order within each pair to reduce drift between variants.
        for position in range(2):
            var started = perf_counter_ns()
            if (measurement + position) % 2 == 0:
                allocating_checksum = _allocating(gradient, count, iterations)
                allocated_times.append(perf_counter_ns() - started)
            else:
                reused_checksum = _reused(gradient, results, iterations)
                reused_times.append(perf_counter_ns() - started)
        assert_equal(allocating_checksum, reused_checksum)
        checksum += allocating_checksum
    _print(name, "colors_allocating", count, iterations, allocated_times, checksum)
    _print(name, "colors_into_reused", count, iterations, reused_times, checksum)


def main() raises:
    print("schema=akari-gradient-benchmark-v1 warmups=2 measurements=11 order=alternating_pairs")
    for count in [16, 65_536]:
        _measure(MixSpace.STORED, "stored", count)
        _measure(MixSpace.LINEAR, "linear", count)
        _measure(MixSpace.OKLAB, "oklab", count)
