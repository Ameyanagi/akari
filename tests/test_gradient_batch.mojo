"""Caller-owned gradient output stays exactly equivalent to scalar sampling."""

from akari import Gradient, MixSpace, RGBA
from std.collections import List
from std.testing import TestSuite, assert_equal, assert_raises, assert_true


def _gradient(space: MixSpace) raises -> Gradient:
    var stops: List[RGBA] = [
        RGBA(0.1, 0.2, 0.8, 0.0),
        RGBA(0.8, 0.1, 0.3, 0.25),
        RGBA(0.3, 0.7, 0.2, 0.5),
        RGBA(0.4, 0.2, 0.9, 0.75),
        RGBA(0.9, 0.8, 0.1, 1.0),
    ]
    return Gradient(stops^, space)


def test_map_into_matches_scalar_for_special_values_and_every_small_length() raises:
    var special: List[Float64] = [
        Float64("-inf"),
        -1.0,
        -0.0,
        0.0,
        0.125,
        0.25,
        0.5,
        0.75,
        0.875,
        1.0,
        2.0,
        Float64("inf"),
        Float64("nan"),
    ]
    for space in [MixSpace.STORED, MixSpace.LINEAR, MixSpace.OKLAB]:
        var gradient = _gradient(space)
        for count in range(34):
            var coordinates = List[Float64](capacity=count)
            for index in range(count):
                coordinates.append(special[index % len(special)])
            var results = List[RGBA](length=count, fill=RGBA.BLACK)
            var capacity = results.capacity()
            gradient.map_into(coordinates, results)
            for index in range(count):
                assert_true(results[index] == gradient.at(coordinates[index]))
            assert_equal(results.capacity(), capacity)


def test_colors_into_matches_allocating_and_scalar_endpoint_contracts() raises:
    for space in [MixSpace.STORED, MixSpace.LINEAR, MixSpace.OKLAB]:
        var gradient = _gradient(space)
        for count in [0, 1, 2, 3, 17, 1024]:
            var results = List[RGBA](length=count, fill=RGBA.BLACK)
            var expected = gradient.colors(count)
            var capacity = results.capacity()
            gradient.colors_into(results)
            assert_equal(len(results), count)
            assert_equal(results.capacity(), capacity)
            for index in range(count):
                var coordinate = 0.0 if count == 1 else Float64(index) / Float64(
                    count - 1
                )
                assert_true(results[index] == gradient.at(coordinate))
                assert_true(results[index] == expected[index])
            if count > 0:
                assert_true(results[0] == gradient.at(0.0))
            if count > 1:
                assert_true(results[count - 1] == gradient.at(1.0))


def test_map_into_rejects_length_mismatch_before_writing() raises:
    var gradient = _gradient(MixSpace.OKLAB)
    var coordinates: List[Float64] = [0.0, 1.0]
    for count in [0, 1, 3]:
        var results = List[RGBA](length=count, fill=RGBA.RED)
        with assert_raises(
            contains=String(
                "results length must equal coordinates length 2; got ", count
            )
        ):
            gradient.map_into(coordinates, results)
        for result in results:
            assert_true(result == RGBA.RED)
    var empty = List[Float64]()
    var one: List[RGBA] = [RGBA.RED]
    with assert_raises(
        contains="results length must equal coordinates length 0; got 1"
    ):
        gradient.map_into(empty, one)
    assert_true(one[0] == RGBA.RED)


def test_reused_output_and_subspans_preserve_surrounding_storage() raises:
    var gradient = _gradient(MixSpace.LINEAR)
    var coordinates: List[Float64] = [0.125, 0.5, 0.875]
    var results = List[RGBA](length=5, fill=RGBA.RED)
    var capacity = results.capacity()
    gradient.map_into(coordinates, Span[mut=True](results)[1:4])
    assert_true(results[0] == RGBA.RED and results[4] == RGBA.RED)
    for index in range(3):
        assert_true(results[index + 1] == gradient.at(coordinates[index]))
    gradient.colors_into(Span[mut=True](results)[1:4])
    assert_true(results[0] == RGBA.RED and results[4] == RGBA.RED)
    for index in range(3):
        assert_true(results[index + 1] == gradient.at(Float64(index) / 2.0))
    assert_equal(results.capacity(), capacity)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
