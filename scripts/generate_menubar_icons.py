#!/usr/bin/env python3
"""Generate menu bar template icons with zombie face pixel art.

Same bullet-hit zombie face style as AppIcon, but monochrome (black + alpha)
for macOS menu bar template images. Draws at 18x18 canvas.

Icon sets:
- ZombieSleep: OFF state - eyes closed, Zzz
- ZombieOn_01~04: ON loop - eyes open, blood drip animation
- ZombieWake_01~02: OFF→ON transition
- ZombieSleepTrans_01~03: ON→OFF transition
"""

import json
from pathlib import Path

from PIL import Image

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
ASSETS = PROJECT_ROOT / "Neverdie" / "Resources" / "Assets.xcassets"

# Canvas size for menu bar icon
SIZE = 18
BLACK = (0, 0, 0, 255)
TRANSPARENT = (0, 0, 0, 0)
# Lighter black for subtle details
LIGHT = (0, 0, 0, 160)
FAINT = (0, 0, 0, 100)


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)


def px(img: Image.Image, x: int, y: int, color=BLACK):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), color)


def draw_base_head(img: Image.Image):
    """Draw the base zombie head outline and fill - common to all frames."""
    # Head outline - rounded rectangle shape
    # Top (row 1-2)
    for x in range(5, 13):
        px(img, x, 1)
    for x in range(4, 14):
        px(img, x, 2)

    # Sides (row 3-12)
    for y in range(3, 13):
        px(img, 3, y)
        px(img, 14, y)

    # Bottom jaw (row 13-14)
    for x in range(4, 14):
        px(img, x, 13)
    for x in range(5, 13):
        px(img, x, 14)

    # Fill interior with light shade for face area
    for y in range(2, 14):
        for x in range(4, 14):
            if img.getpixel((x, y))[3] == 0:
                px(img, x, y, FAINT)

    # Hair on top - messy spikes
    for x in [5, 7, 9, 11]:
        px(img, x, 0)
    for x in range(5, 13):
        px(img, x, 1)
    px(img, 6, 2)
    px(img, 8, 2)
    px(img, 10, 2)
    px(img, 12, 2)


def draw_bullet_hole(img: Image.Image):
    """Draw bullet hole on right forehead."""
    px(img, 11, 3)
    px(img, 12, 3)
    px(img, 12, 4)
    px(img, 13, 4, LIGHT)  # crack


def draw_nose(img: Image.Image):
    """Draw simple nose."""
    px(img, 8, 8, LIGHT)
    px(img, 9, 8)


def draw_mouth_stitched(img: Image.Image):
    """Draw stitched zombie mouth with teeth."""
    # Mouth line
    for x in range(5, 13):
        px(img, x, 10)
    # Teeth
    px(img, 6, 11, LIGHT)
    px(img, 8, 11, LIGHT)
    px(img, 10, 11, LIGHT)
    px(img, 12, 11, LIGHT)
    # Stitch marks
    px(img, 6, 9, LIGHT)
    px(img, 8, 9, LIGHT)
    px(img, 10, 9, LIGHT)
    px(img, 12, 9, LIGHT)


# =====================================================
# ON frames - arrow flying into zombie head
# =====================================================
# Frame 1: Arrow approaching from right
# Frame 2: Arrow hitting head, zombie shocked
# Frame 3: Arrow stuck in head, impact stars
# Frame 4: Arrow in head, zombie fine (neverdie!)


def draw_eyes_normal(img: Image.Image):
    """Normal open eyes."""
    # Left eye
    for x in range(5, 8):
        px(img, x, 5)
        px(img, x, 7)
    px(img, 4, 6)
    px(img, 8, 6)
    px(img, 6, 6)  # pupil

    # Right eye
    for x in range(10, 13):
        px(img, x, 5)
        px(img, x, 7)
    px(img, 9, 6)
    px(img, 13, 6)
    px(img, 11, 6)  # pupil


def draw_eyes_looking_right(img: Image.Image):
    """Eyes looking right - sees arrow coming!"""
    # Left eye
    for x in range(5, 8):
        px(img, x, 5)
        px(img, x, 7)
    px(img, 4, 6)
    px(img, 8, 6)
    px(img, 7, 6)  # pupil right

    # Right eye (wide!)
    for x in range(10, 13):
        px(img, x, 5)
        px(img, x, 7)
    px(img, 9, 6)
    px(img, 13, 6)
    px(img, 12, 6)  # pupil right


def draw_eyes_shocked(img: Image.Image):
    """Eyes X_X shocked from impact."""
    # Left eye - X shape
    px(img, 5, 5)
    px(img, 7, 5)
    px(img, 6, 6)
    px(img, 5, 7)
    px(img, 7, 7)

    # Right eye - X shape
    px(img, 10, 5)
    px(img, 12, 5)
    px(img, 11, 6)
    px(img, 10, 7)
    px(img, 12, 7)


def draw_eyes_smug(img: Image.Image):
    """Smug eyes - I'm still alive!"""
    # Left eye - half-lid smug
    for x in range(5, 8):
        px(img, x, 5)
    px(img, 4, 6)
    px(img, 8, 6)
    px(img, 6, 6)  # pupil
    for x in range(5, 8):
        px(img, x, 7, LIGHT)

    # Right eye - winking
    for x in range(10, 13):
        px(img, x, 6)


def draw_arrow_approaching(img: Image.Image):
    """Arrow flying in from the right side."""
    # Arrow shaft -->
    px(img, 17, 4)
    px(img, 16, 4)
    px(img, 15, 4)
    # Arrow head (triangle)
    px(img, 14, 4)
    px(img, 15, 3)
    px(img, 15, 5)


def draw_arrow_hitting(img: Image.Image):
    """Arrow just hitting the head."""
    # Arrow sticking into right side of head
    px(img, 17, 4)
    px(img, 16, 4)
    px(img, 15, 4)
    px(img, 14, 4)
    # Impact star/spark
    px(img, 13, 3)
    px(img, 13, 5)
    px(img, 15, 3, LIGHT)
    px(img, 15, 5, LIGHT)


def draw_arrow_stuck(img: Image.Image):
    """Arrow stuck through the head."""
    # Arrow shaft going through head
    px(img, 17, 4)
    px(img, 16, 4)
    px(img, 15, 4)
    # Arrow tip poking out left side
    px(img, 2, 4)
    px(img, 1, 3)
    px(img, 1, 5)


def draw_impact_stars(img: Image.Image):
    """Small impact stars around the head."""
    px(img, 1, 1, LIGHT)
    px(img, 16, 1, LIGHT)
    px(img, 0, 7, LIGHT)
    px(img, 17, 8, LIGHT)


# =====================================================
# OFF frame - sleeping
# =====================================================


def draw_eyes_closed(img: Image.Image):
    """Eyes closed - sleeping."""
    # Left eye - closed line
    for x in range(5, 8):
        px(img, x, 6)

    # Right eye - closed line
    for x in range(10, 13):
        px(img, x, 6)


def draw_zzz(img: Image.Image):
    """Draw Zzz for sleeping."""
    # Big Z
    px(img, 14, 0)
    px(img, 15, 0)
    px(img, 16, 0)
    px(img, 15, 1)
    px(img, 14, 2)
    px(img, 15, 2)
    px(img, 16, 2)
    # Small z
    px(img, 16, 3, LIGHT)
    px(img, 17, 3, LIGHT)
    px(img, 16, 4, LIGHT)
    px(img, 17, 4, LIGHT)


# =====================================================
# Transition frames
# =====================================================


def draw_eyes_half_open(img: Image.Image):
    """Eyes half open - waking up / falling asleep."""
    # Left eye half
    for x in range(5, 8):
        px(img, x, 6)
    px(img, 5, 5, LIGHT)
    px(img, 7, 5, LIGHT)

    # Right eye barely open
    for x in range(10, 13):
        px(img, x, 6)


def draw_eyes_squint(img: Image.Image):
    """Both eyes squinting."""
    for x in range(5, 8):
        px(img, x, 6)
        px(img, x, 5, FAINT)

    for x in range(10, 13):
        px(img, x, 6)
        px(img, x, 5, FAINT)


# =====================================================
# Compose frames
# =====================================================


def make_on_frame(eye_func, arrow_func=None, stars=False) -> Image.Image:
    img = new_canvas()
    draw_base_head(img)
    draw_bullet_hole(img)
    eye_func(img)
    draw_nose(img)
    draw_mouth_stitched(img)
    if arrow_func:
        arrow_func(img)
    if stars:
        draw_impact_stars(img)
    return img


def make_sleep_frame() -> Image.Image:
    img = new_canvas()
    draw_base_head(img)
    draw_bullet_hole(img)
    draw_eyes_closed(img)
    draw_nose(img)
    draw_mouth_stitched(img)
    draw_zzz(img)
    return img


def make_transition_frame(eye_func) -> Image.Image:
    img = new_canvas()
    draw_base_head(img)
    draw_bullet_hole(img)
    eye_func(img)
    draw_nose(img)
    draw_mouth_stitched(img)
    return img


def save_imageset(name: str, img_1x: Image.Image):
    """Save 1x and 2x versions to the asset catalog."""
    imageset_dir = ASSETS / f"{name}.imageset"
    imageset_dir.mkdir(exist_ok=True)

    # Read existing Contents.json to get filenames
    contents_path = imageset_dir / "Contents.json"
    if contents_path.exists():
        existing = json.loads(contents_path.read_text())
        filenames = {}
        for entry in existing.get("images", []):
            if "filename" in entry:
                filenames[entry["scale"]] = entry["filename"]
        fn_1x = filenames.get("1x", f"{name.lower()}_1x.png")
        fn_2x = filenames.get("2x", f"{name.lower()}_2x.png")
    else:
        fn_1x = f"{name.lower()}_1x.png"
        fn_2x = f"{name.lower()}_2x.png"

    # Save 1x (18x18)
    img_1x.save(imageset_dir / fn_1x, "PNG")

    # Save 2x (36x36) - scale up with nearest neighbor
    img_2x = img_1x.resize((SIZE * 2, SIZE * 2), Image.NEAREST)
    img_2x.save(imageset_dir / fn_2x, "PNG")

    # Write Contents.json
    contents = {
        "images": [
            {"filename": fn_1x, "idiom": "universal", "scale": "1x"},
            {"filename": fn_2x, "idiom": "universal", "scale": "2x"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "template"},
    }
    contents_path.write_text(json.dumps(contents, indent=2) + "\n")
    print(f"  {name}: {fn_1x}, {fn_2x}")


def main():
    print("Generating menu bar zombie face icons...")

    # ON loop frames: arrow flies in → hits → stuck → zombie smug
    on_01 = make_on_frame(draw_eyes_looking_right, arrow_func=draw_arrow_approaching)
    on_02 = make_on_frame(draw_eyes_shocked, arrow_func=draw_arrow_hitting)
    on_03 = make_on_frame(draw_eyes_shocked, arrow_func=draw_arrow_stuck, stars=True)
    on_04 = make_on_frame(draw_eyes_smug, arrow_func=draw_arrow_stuck)

    save_imageset("ZombieOn_01", on_01)
    save_imageset("ZombieOn_02", on_02)
    save_imageset("ZombieOn_03", on_03)
    save_imageset("ZombieOn_04", on_04)

    # OFF frame (sleeping)
    sleep = make_sleep_frame()
    save_imageset("ZombieSleep", sleep)

    # Wake up transition (OFF→ON): closed → half → open
    wake_01 = make_transition_frame(draw_eyes_half_open)
    wake_02 = make_transition_frame(draw_eyes_normal)
    save_imageset("ZombieWake_01", wake_01)
    save_imageset("ZombieWake_02", wake_02)

    # Fall asleep transition (ON→OFF): open → squint → half → closed
    sleep_trans_01 = make_transition_frame(draw_eyes_squint)
    sleep_trans_02 = make_transition_frame(draw_eyes_half_open)
    sleep_trans_03 = make_transition_frame(draw_eyes_closed)
    save_imageset("ZombieSleepTrans_01", sleep_trans_01)
    save_imageset("ZombieSleepTrans_02", sleep_trans_02)
    save_imageset("ZombieSleepTrans_03", sleep_trans_03)

    # AutoOff frames (reuse sleep transition style)
    save_imageset("ZombieAutoOff_01", on_04)
    save_imageset("ZombieAutoOff_02", sleep_trans_01)
    save_imageset("ZombieAutoOff_03", sleep_trans_02)
    save_imageset("ZombieAutoOff_04", sleep_trans_03)

    # Save references for inspection
    ref_dir = SCRIPT_DIR / "menubar_refs"
    ref_dir.mkdir(exist_ok=True)
    for name_img, img in [
        ("on_01", on_01),
        ("on_02", on_02),
        ("on_03", on_03),
        ("on_04", on_04),
        ("sleep", sleep),
        ("wake_01", wake_01),
        ("wake_02", wake_02),
        ("sleeptrans_01", sleep_trans_01),
        ("sleeptrans_02", sleep_trans_02),
        ("sleeptrans_03", sleep_trans_03),
    ]:
        # Save 4x scaled for easier inspection
        big = img.resize((SIZE * 4, SIZE * 4), Image.NEAREST)
        big.save(ref_dir / f"{name_img}_4x.png", "PNG")

    print(f"\nReference images saved to {ref_dir}/")
    print("Done!")


if __name__ == "__main__":
    main()
