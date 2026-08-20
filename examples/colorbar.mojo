from akari import Colormap


def main():
    var colors = Colormap.VIRIDIS.colors(256)
    for index in range(len(colors)):
        var stored = colors[index].stored_bytes()
        print(index, stored[0], stored[1], stored[2])
