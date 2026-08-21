from akari import MixSpace
from std.testing import TestSuite, assert_true


def test_constants_are_nominal_and_distinct() raises:
    var stored = MixSpace.STORED
    var other_stored = MixSpace.STORED
    var linear = MixSpace.LINEAR
    var oklab = MixSpace.OKLAB
    assert_true(stored == other_stored)
    assert_true(stored != linear)
    assert_true(stored != oklab)
    assert_true(linear != oklab)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
