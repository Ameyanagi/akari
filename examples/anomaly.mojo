from akari import Colormap
from std.collections import List


def main() raises:
    var anomalies: List[Float64] = [-3.0, -1.5, -0.25, 0.0, 0.75, 2.0, 3.0]
    var colors = Colormap.RED_BLUE.map(anomalies, -3.0, 3.0)
    var stored = Colormap.RED_BLUE.map_bytes(anomalies, -3.0, 3.0)
    for index in range(len(anomalies)):
        print(
            anomalies[index],
            "-> rgb(",
            stored[index][0],
            ",",
            stored[index][1],
            ",",
            stored[index][2],
            ") alpha=",
            colors[index].alpha(),
        )
