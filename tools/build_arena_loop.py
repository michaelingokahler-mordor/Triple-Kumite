"""Build the transparent water loop for Godot and a full arena GIF preview."""

import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
FRAMES = 24
FRAME_WIDTH = 192
FRAME_HEIGHT = 64
ORIGIN = (270, 211)


def build_frame(index):
    frame = Image.new("RGBA", (FRAME_WIDTH, FRAME_HEIGHT))
    draw = ImageDraw.Draw(frame)
    angle = math.tau * index / FRAMES
    for ripple in range(15):
        base_y = 4 + 3 * ripple
        phase = angle * (1 if ripple % 3 else 2) + ripple * 1.28
        wave = (math.sin(phase) + 1.0) / 2.0
        length = round(5 + wave * (8 + ripple * 0.7))
        x = round(99 + math.cos(ripple * 2.3) * (15 + ripple * 2.0) + math.sin(phase) * 4)
        y = base_y + round(math.sin(phase) * 1.3)
        opacity = round(17 + wave * 122)
        color = (255, 179, 93, opacity) if ripple % 3 else (250, 128, 97, opacity)
        draw.rectangle((x, y, x + length, y), fill=color)
        if ripple % 4 == 0:
            draw.rectangle((x + 1, y + 1, x + max(3, length // 2), y + 1), fill=(255, 202, 112, opacity // 2))
    for ripple in range(5):
        phase = angle + ripple * 1.7
        x = 29 + ripple * 31 + round(3 * math.cos(phase))
        y = 18 + (ripple * 11) % 42
        draw.rectangle((x, y, x + 5, y), fill=(155, 136, 208, round(20 + 36 * (math.sin(phase) + 1))))
    return frame


def main():
    atlas = Image.new("RGBA", (FRAME_WIDTH * 6, FRAME_HEIGHT * 4))
    backdrop = Image.open(ROOT / "assets" / "arena.png").convert("RGBA")
    previews = []
    for index in range(FRAMES):
        frame = build_frame(index)
        atlas.paste(frame, ((index % 6) * FRAME_WIDTH, (index // 6) * FRAME_HEIGHT))
        preview = backdrop.copy()
        preview.alpha_composite(frame, ORIGIN)
        previews.append(preview.convert("RGB"))
    atlas.save(ROOT / "assets" / "arena-ripples.png", optimize=True)
    (ROOT / "build").mkdir(exist_ok=True)
    previews[0].save(
        ROOT / "build" / "Coast-Dojo-Arena.gif",
        save_all=True,
        append_images=previews[1:],
        duration=90,
        loop=0,
        optimize=True,
    )


if __name__ == "__main__":
    main()
