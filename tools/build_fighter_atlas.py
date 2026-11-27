"""Extract Runway fighter art into three colorways on a shared pixel grid."""

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CELL_WIDTH = 108
CELL_HEIGHT = 80
ANCHOR_X = 54
GROUND_Y = 74
SCALE = 60 / 445

# Source sheet, cell index, horizontal anchor within the silhouette, raised feet.
POSES = [
    (0, 0, 0.48, 0),   # guard
    (0, 1, 0.48, 0),   # alternate guard
    (0, 2, 0.49, 0),   # walk contact
    (1, 11, 0.49, 0),  # walk passing
    (0, 4, 0.46, 0),   # block
    (0, 5, 0.40, 0),   # punch
    (0, 6, 0.47, 0),   # crouching punch
    (0, 7, 0.43, 0),   # headbutt
    (0, 8, 0.28, 0),   # shin kick
    (0, 9, 0.32, 0),   # body kick
    (0, 10, 0.30, 0),  # high kick
    (1, 0, 0.36, 0),   # sweep
    (0, 12, 0.47, 4),  # jump
    (0, 13, 0.35, 7),  # flying kick
    (1, 1, 0.50, 15),  # double kick
    (0, 15, 0.55, 0),  # prone
    (1, 2, 0.56, 4),   # backflip
    (1, 4, 0.55, 0),   # hit reaction
    (1, 5, 0.55, 0),   # fall
    (1, 6, 0.50, 0),   # rise
    (1, 9, 0.49, 0),   # walk alternate contact
    (1, 10, 0.49, 0),  # walk alternate passing
]


def extract(source, index):
    width, height = source.width // 4, source.height // 4
    x, y = (index % 4) * width, (index // 4) * height
    cell = source.crop((x + 7, y + 7, x + width - 7, y + height - 7))
    pixels = []
    for red, green, blue in cell.getdata():
        if red > 90 and blue > 105 and min(red, blue) > green * 1.32 + 34:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, 255))
    sprite = Image.new("RGBA", cell.size)
    sprite.putdata(pixels)
    bounds = sprite.getbbox()
    if not bounds:
        raise ValueError(f"Sprite cell {index} is empty")
    sprite = sprite.crop(bounds)
    size = (max(1, round(sprite.width * SCALE)), max(1, round(sprite.height * SCALE)))
    return sprite.resize(size, Image.Resampling.NEAREST)


def uniform(sprite, dark, light):
    recolored = sprite.copy()
    pixels = []
    for red, green, blue, alpha in sprite.getdata():
        if alpha and blue >= red - 4 and green >= red - 5 and min(red, green, blue) > 55:
            level = max(0.0, min(1.0, ((red + green + blue) / 3 - 70) / 170))
            color = tuple(round(a + (b - a) * level) for a, b in zip(dark, light))
            pixels.append((*color, alpha))
        else:
            pixels.append((red, green, blue, alpha))
    recolored.putdata(pixels)
    return recolored


def low_shield_pose(source):
    """Anchor the generated shield boss at (15, -21) from the fighter origin."""
    shield_x, shield_y = 765, 615
    feet_y = 934
    scale = (feet_y - shield_y) / 21
    left = shield_x - (ANCHOR_X + 15) * scale
    top = feet_y - GROUND_Y * scale
    sprite = source.convert("RGB").transform(
        (CELL_WIDTH, CELL_HEIGHT),
        Image.Transform.AFFINE,
        (scale, 0, left, 0, scale, top),
        Image.Resampling.NEAREST,
        fillcolor=(255, 0, 255),
    )
    pixels = []
    for red, green, blue in sprite.getdata():
        if red > 90 and blue > 105 and min(red, blue) > green * 1.32 + 34:
            pixels.append((0, 0, 0, 0))
        elif red > 24 and min(red, blue) > green + 14:
            pixels.append((9, 15, 45, 255))
        else:
            pixels.append((red, green, blue, 255))
    result = Image.new("RGBA", sprite.size)
    result.putdata(pixels)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("main_sheet", type=Path)
    parser.add_argument("extra_sheet", type=Path)
    parser.add_argument("low_shield", type=Path)
    args = parser.parse_args()
    sheets = [Image.open(path).convert("RGB") for path in (args.main_sheet, args.extra_sheet)]
    columns = 6
    rows = (len(POSES) + columns - 1) // columns
    atlas = Image.new("RGBA", (columns * CELL_WIDTH, rows * CELL_HEIGHT * 3))
    for index, (source, cell, anchor, lift) in enumerate(POSES):
        sprite = extract(sheets[source], cell)
        x = (index % columns) * CELL_WIDTH + ANCHOR_X - round(sprite.width * anchor)
        y = (index // columns) * CELL_HEIGHT + GROUND_Y - sprite.height - lift
        colorways = [
            sprite,
            uniform(sprite, (75, 25, 45), (244, 107, 101)),
            uniform(sprite, (27, 55, 98), (105, 192, 243)),
        ]
        for palette, image in enumerate(colorways):
            atlas.paste(image, (x, y + palette * rows * CELL_HEIGHT))
    # Cell 22 is unused in all three palette blocks.
    sprite = low_shield_pose(Image.open(args.low_shield))
    for palette, image in enumerate([
        sprite,
        uniform(sprite, (75, 25, 45), (244, 107, 101)),
        uniform(sprite, (27, 55, 98), (105, 192, 243)),
    ]):
        atlas.paste(image, (4 * CELL_WIDTH, (3 + palette * rows) * CELL_HEIGHT))
    atlas.save(ROOT / "assets" / "karateka.png", optimize=True)


if __name__ == "__main__":
    main()
