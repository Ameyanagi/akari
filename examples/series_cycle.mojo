from akari import Palette


def main():
    var palette = Palette.tableau10()
    for index in range(12):
        print(index, palette.cycle(index).hex())
