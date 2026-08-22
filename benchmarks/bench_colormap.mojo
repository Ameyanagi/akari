"""Reproducible allocation-free colormap throughput benchmark."""

from akari import Colormap, RGBA
from std.benchmark import keep
from std.collections import List
from std.time import perf_counter_ns


comptime _SAMPLE_BUDGET = 1 << 21
comptime _MEASUREMENTS = 31
comptime _WARMUP_ROUNDS = 2


def _values(count: Int) raises -> List[Float64]:
    """Build a deterministic mix of interior, clamped, and missing values."""
    var values = List[Float64](capacity=count)
    for index in range(count):
        if index % 257 == 0:
            values.append(Float64("nan"))
        elif index % 251 == 0:
            values.append(Float64("inf"))
        elif index % 241 == 0:
            values.append(Float64("-inf"))
        else:
            values.append(Float64((index * 73) % 2048) / 1024.0 - 0.5)
    return values^


def _sort(mut values: List[Int]):
    # Thirty-one samples keep this benchmark-only insertion sort negligible.
    for index in range(1, len(values)):
        var value = values[index]
        var position = index
        while position > 0 and values[position - 1] > value:
            values[position] = values[position - 1]
            position -= 1
        values[position] = value


def _percentiles(mut elapsed: List[Int]) -> Tuple[Int, Int]:
    _sort(elapsed)
    return (
        elapsed[_MEASUREMENTS // 2],
        elapsed[(_MEASUREMENTS * 95 + 99) // 100 - 1],
    )


def _measure_colors(count: Int) raises:
    var values = _values(count)
    var results = List[RGBA](length=count, fill=RGBA.BLACK)
    var iterations = max(1, _SAMPLE_BUDGET // count)
    for _ in range(_WARMUP_ROUNDS):
        for _ in range(iterations):
            Colormap.VIRIDIS.map_into(values, 0.0, 1.0, results)
        keep(results[count - 1].green())

    var elapsed = List[Int](capacity=_MEASUREMENTS)
    var checksum = 0.0
    for sample in range(_MEASUREMENTS):
        var started = perf_counter_ns()
        for _ in range(iterations):
            Colormap.VIRIDIS.map_into(values, 0.0, 1.0, results)
        elapsed.append(perf_counter_ns() - started)
        checksum += results[(sample * 8191) % count].green()
        keep(checksum)
    var percentiles = _percentiles(elapsed)

    print(
        "case=map_into count=",
        count,
        " iterations=",
        iterations,
        " mapped_samples=",
        count * iterations,
        " p50_elapsed_ns=",
        percentiles[0],
        " p95_elapsed_ns=",
        percentiles[1],
        " p50_ns_per_value=",
        Float64(percentiles[0]) / Float64(count * iterations),
        " p95_ns_per_value=",
        Float64(percentiles[1]) / Float64(count * iterations),
        " checksum=",
        checksum,
        sep="",
    )


def _measure_bytes(count: Int) raises:
    var values = _values(count)
    var results = List[SIMD[DType.uint8, 4]](
        length=count, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    var iterations = max(1, _SAMPLE_BUDGET // count)
    for _ in range(_WARMUP_ROUNDS):
        for _ in range(iterations):
            Colormap.VIRIDIS.map_bytes_into(values, 0.0, 1.0, results)
        keep(results[count - 1][1])

    var elapsed = List[Int](capacity=_MEASUREMENTS)
    var checksum = UInt64(0)
    for sample in range(_MEASUREMENTS):
        var started = perf_counter_ns()
        for _ in range(iterations):
            Colormap.VIRIDIS.map_bytes_into(values, 0.0, 1.0, results)
        elapsed.append(perf_counter_ns() - started)
        checksum += UInt64(results[(sample * 8191) % count][1])
        keep(checksum)
    var percentiles = _percentiles(elapsed)

    print(
        "case=map_bytes_into count=",
        count,
        " iterations=",
        iterations,
        " mapped_samples=",
        count * iterations,
        " p50_elapsed_ns=",
        percentiles[0],
        " p95_elapsed_ns=",
        percentiles[1],
        " p50_ns_per_value=",
        Float64(percentiles[0]) / Float64(count * iterations),
        " p95_ns_per_value=",
        Float64(percentiles[1]) / Float64(count * iterations),
        " checksum=",
        checksum,
        sep="",
    )


def _assert_full_buffer_equivalence(count: Int) raises:
    var values = _values(count)
    var colors = List[RGBA](length=count, fill=RGBA.BLACK)
    var bytes = List[SIMD[DType.uint8, 4]](
        length=count, fill=SIMD[DType.uint8, 4](0, 0, 0, 0)
    )
    Colormap.VIRIDIS.map_into(values, 0.0, 1.0, colors)
    Colormap.VIRIDIS.map_bytes_into(values, 0.0, 1.0, bytes)
    for index in range(count):
        if bytes[index] != colors[index].stored_bytes():
            raise Error(
                String("color/byte kernel mismatch at index ", index, " of ", count)
            )
    print(
        "verification=full_buffer_equivalence count=",
        count,
        " status=passed",
        sep="",
    )


def main() raises:
    print(
        "schema=akari-colormap-benchmark-v4 ",
        "mojo=1.0.0 statistic=p50_p95_of_31 ",
        "warmup_rounds=2 sample_budget=2097152",
        sep="",
    )
    for count in [1024, 65536, 1048576]:
        _assert_full_buffer_equivalence(count)
        _measure_colors(count)
        _measure_bytes(count)
