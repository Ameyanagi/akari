from akari import RGBA


def main() raises:
    var shadow = RGBA(0.08, 0.10, 0.16)
    var highlight = RGBA(0.76, 0.88, 1.0)
    var midpoint = shadow.lerp(highlight, 0.5)
    print(midpoint.red(), midpoint.green(), midpoint.blue(), midpoint.alpha())
