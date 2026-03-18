#!/usr/bin/env python3
"""Generate macOS AppIcon with hand-drawn pixel art zombie face.

Draws a bullet-hit zombie face in pixel art style on a bright background.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
ASSETS = PROJECT_ROOT / "Neverdie" / "Resources" / "Assets.xcassets"
APPICON_DIR = ASSETS / "AppIcon.appiconset"

ICON_SPECS = [
    (16, 1),
    (16, 2),
    (32, 1),
    (32, 2),
    (128, 1),
    (128, 2),
    (256, 1),
    (256, 2),
    (512, 1),
    (512, 2),
]

# Bright mint/teal background
BG_COLOR = (130, 210, 180, 255)
CORNER_RADIUS_FRAC = 0.185


def draw_zombie_face() -> Image.Image:
    """Draw a 32x32 pixel art zombie face that survived being shot."""
    size = 32
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Color palette
    skin = (120, 160, 90)  # zombie green skin
    skin_dark = (90, 130, 70)  # darker green for shading
    eye_white = (220, 220, 200)  # yellowish whites
    pupil = (180, 30, 30)  # red pupils
    mouth = (60, 40, 40)  # dark mouth
    teeth = (210, 200, 180)  # yellowish teeth
    blood = (160, 30, 30)  # bullet wound blood
    blood_drip = (140, 25, 25)  # darker blood drip
    hair = (50, 40, 35)  # dark messy hair
    outline = (40, 50, 30)  # dark green outline
    scar = (100, 140, 75)  # scar tissue
    bullet_hole = (80, 20, 20)  # dark bullet hole center

    def px(x, y, color):
        if 0 <= x < size and 0 <= y < size:
            img.putpixel((x, y), color + (255,))

    # --- Head outline (rounded rectangular shape) ---
    # Top of head (row 6-7)
    for x in range(10, 22):
        px(x, 6, outline)
    for x in range(9, 23):
        px(x, 7, outline)

    # Sides of head (row 8-23)
    for y in range(8, 24):
        px(8, y, outline)
        px(23, y, outline)

    # Bottom / jaw (row 24-26)
    for x in range(9, 23):
        px(x, 24, outline)
    for x in range(10, 22):
        px(x, 25, outline)
    for x in range(12, 20):
        px(x, 26, outline)

    # --- Fill skin ---
    for y in range(7, 25):
        for x in range(9, 23):
            if img.getpixel((x, y))[3] == 0:
                px(x, y, skin)
    for x in range(10, 22):
        if img.getpixel((x, 25))[3] == 0:
            px(x, 25, skin)
    for x in range(12, 20):
        if img.getpixel((x, 26))[3] == 0:
            px(x, 26, skin_dark)

    # --- Messy hair on top ---
    for x in range(10, 22):
        px(x, 5, hair)
    for x in [9, 10, 13, 14, 17, 18, 21, 22]:
        px(x, 4, hair)
    for x in [10, 14, 18]:
        px(x, 3, hair)
    # Hair over forehead
    for x in range(10, 22):
        px(x, 7, hair)
    for x in [10, 11, 15, 16, 20, 21]:
        px(x, 8, hair)

    # --- Eyes (asymmetric - one squinting from bullet impact) ---
    # Left eye - wide open, shocked
    for x in range(11, 15):
        px(x, 12, outline)
        px(x, 15, outline)
    px(10, 13, outline)
    px(10, 14, outline)
    px(15, 13, outline)
    px(15, 14, outline)
    # Eye whites
    for x in range(11, 15):
        for y in range(13, 15):
            px(x, y, eye_white)
    # Red pupil
    px(12, 13, pupil)
    px(13, 13, pupil)
    px(12, 14, pupil)
    px(13, 14, pupil)

    # Right eye - squinting/damaged from bullet
    for x in range(17, 21):
        px(x, 13, outline)
        px(x, 14, outline)
    px(17, 13, eye_white)
    px(18, 13, pupil)
    px(19, 13, eye_white)
    px(20, 13, eye_white)

    # --- Bullet hole on right forehead! ---
    px(19, 9, bullet_hole)
    px(20, 9, bullet_hole)
    px(19, 10, bullet_hole)
    px(20, 10, blood)
    px(21, 10, blood)
    px(18, 10, blood)
    # Blood dripping from bullet hole
    px(19, 11, blood)
    px(20, 11, blood_drip)
    px(20, 12, blood_drip)
    px(19, 12, blood)
    # Crack lines from bullet hole
    px(18, 9, scar)
    px(21, 9, scar)
    px(21, 11, blood)

    # --- Nose ---
    px(15, 16, outline)
    px(16, 16, outline)
    px(15, 17, skin_dark)
    px(16, 17, outline)

    # --- Mouth - stitched grin ---
    # Mouth opening
    for x in range(11, 21):
        px(x, 20, mouth)
    for x in range(12, 20):
        px(x, 21, mouth)

    # Teeth (uneven, zombie-like)
    px(12, 20, teeth)
    px(14, 20, teeth)
    px(16, 20, teeth)
    px(19, 20, teeth)
    # Bottom teeth
    px(13, 21, teeth)
    px(15, 21, teeth)
    px(18, 21, teeth)

    # Stitch marks across mouth
    px(11, 19, outline)
    px(13, 19, outline)
    px(15, 19, outline)
    px(17, 19, outline)
    px(19, 19, outline)

    # --- Scars ---
    # Left cheek scar
    px(10, 17, scar)
    px(10, 18, scar)
    px(11, 18, scar)

    # --- Blood drip from mouth corner ---
    px(11, 22, blood)
    px(11, 23, blood_drip)

    # --- Shading on edges ---
    for y in range(10, 22):
        px(9, y, skin_dark)
        px(22, y, skin_dark)

    return img


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=255)
    return mask


def create_icon(zombie: Image.Image, pixel_size: int) -> Image.Image:
    icon = Image.new("RGBA", (pixel_size, pixel_size), BG_COLOR)

    # Scale zombie to ~70% of icon size
    zombie_size = max(int(pixel_size * 0.7), 1)
    scaled = zombie.resize((zombie_size, zombie_size), Image.NEAREST)

    offset_x = (pixel_size - zombie_size) // 2
    offset_y = (pixel_size - zombie_size) // 2 + int(
        pixel_size * 0.02
    )  # slightly lower
    icon.paste(scaled, (offset_x, offset_y), scaled)

    radius = max(int(pixel_size * CORNER_RADIUS_FRAC), 1)
    mask = rounded_rect_mask(pixel_size, radius)
    final = Image.new("RGBA", (pixel_size, pixel_size), (0, 0, 0, 0))
    final.paste(icon, mask=mask)
    return final


def main():
    zombie = draw_zombie_face()
    # Save source for reference
    ref_path = SCRIPT_DIR / "zombie_face_reference.png"
    zombie.save(ref_path, "PNG")
    print(f"Saved reference: {ref_path}")

    contents_images = []

    for pt_size, scale in ICON_SPECS:
        px = pt_size * scale
        filename = f"app_icon_{pt_size}x{pt_size}@{scale}x.png"
        filepath = APPICON_DIR / filename

        icon = create_icon(zombie, px)
        icon.save(filepath, "PNG")
        print(f"  Created {filename} ({pt_size}x{pt_size} @{scale}x = {px}px)")

        contents_images.append(
            {
                "filename": filename,
                "idiom": "mac",
                "scale": f"{scale}x",
                "size": f"{pt_size}x{pt_size}",
            }
        )

    contents = {
        "images": contents_images,
        "info": {"author": "xcode", "version": 1},
    }
    contents_path = APPICON_DIR / "Contents.json"
    contents_path.write_text(json.dumps(contents, indent=2) + "\n")
    print(f"\nUpdated {contents_path.name}")
    print("Done!")


if __name__ == "__main__":
    main()
