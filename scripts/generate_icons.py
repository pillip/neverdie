#!/usr/bin/env python3
"""Generate Neverdie menu bar pixel-art icons.

Concept: A zombie riddled with bullet holes that refuses to die.
- OFF (ZombieSleep): slumped zombie with bullet holes, Z's floating
- ON loop (ZombieOn_01~04): zombie shambling with arms out, bullet holes visible
- Wake transition (ZombieWake_01~02): zombie rising from slump
- Sleep transition (ZombieSleepTrans_01~03): zombie slumping back down
- AutoOff (ZombieAutoOff_01~04): zombie dramatically collapsing

All icons are black-on-transparent template images for macOS menu bar.
"""

from pathlib import Path

from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).parent.resolve()
ASSETS_BASE = SCRIPT_DIR.parent / "Neverdie" / "Resources" / "Assets.xcassets"


def create_image(scale: int = 1):
    """Create a transparent image at the given scale (1x=18px, 2x=36px)."""
    size = 18 * scale
    return Image.new("RGBA", (size, size), (0, 0, 0, 0)), scale


def px(img_and_scale, x, y, alpha=255):
    """Draw a pixel at (x, y) in the 18x18 grid, scaled appropriately."""
    img, scale = img_and_scale
    draw = ImageDraw.Draw(img)
    for dx in range(scale):
        for dy in range(scale):
            draw.point((x * scale + dx, y * scale + dy), fill=(0, 0, 0, alpha))


def draw_pixels(img_and_scale, pixels, alpha=255):
    """Draw multiple pixels from a list of (x, y) tuples."""
    for x, y in pixels:
        px(img_and_scale, x, y, alpha)


def draw_bitmap(img_and_scale, bitmap, offset_x=0, offset_y=0, alpha=255):
    """Draw from a string bitmap.

    '#' = pixel, '.' = empty, 'o' = bullet hole (lighter).
    """
    for row_idx, row in enumerate(bitmap):
        for col_idx, ch in enumerate(row):
            if ch == "#":
                px(img_and_scale, col_idx + offset_x, row_idx + offset_y, alpha)
            elif ch == "o":
                px(img_and_scale, col_idx + offset_x, row_idx + offset_y, 140)


# =============================================================================
# Zombie designs (18x18 grid)
# =============================================================================

# Standing zombie body (facing right, arms forward) with bullet holes
ZOMBIE_STANDING = [
    "......##........",  # row 0: top of head
    ".....####.......",  # row 1: head
    ".....####.......",  # row 2: head
    "......##........",  # row 3: neck
    "....######......",  # row 4: shoulders
    "...#o.##.o#.....",  # row 5: torso with bullet holes
    "..#...##...#....",  # row 6: arms out
    ".#....##........",  # row 7: arms
    "......##........",  # row 8: waist
    ".....#..#.......",  # row 9: hips
    ".....#..#.......",  # row 10: upper legs
    "....#....#......",  # row 11: knees
    "....#....#......",  # row 12: lower legs
    "...#......#.....",  # row 13: ankles
    "...##....##.....",  # row 14: feet
]

# Zombie ON frame 1: bullet flying in with trail  ---->>
ZOMBIE_ON_1 = [
    "......###.......",  # head
    ".....#####......",
    ".....#####......",
    "......###.......",  # neck
    ".....#####......",  # shoulders
    "#.#.######......",  # bullet -->> approaching torso
    ".....#####......",
    "......###.......",  # waist
    "......#.#.......",
    ".....#...#......",
    ".....#...#......",
    "....#.....#.....",
    "....##...##.....",
]

# Zombie ON frame 2: BANG! big impact explosion
ZOMBIE_ON_2 = [
    "......###.......",
    ".....#####......",
    ".....#####......",
    "....#.###.......",
    "...#.#####......",  # spark up-left
    "..###o####......",  # BANG! big impact
    "...#.#####......",  # spark down-left
    "....#.###.......",
    "......#.#.......",
    ".....#...#......",
    ".....#...#......",
    "....#.....#.....",
    "....##...##.....",
]

# Zombie ON frame 3: knocked back hard, holes visible
ZOMBIE_ON_3 = [
    "........###.....",
    ".......#####....",
    ".......#####....",  # head knocked back
    "........###.....",
    ".......#####....",
    "......#o####....",  # bullet hole
    ".......####.....",
    "........###.....",
    "........#.#.....",
    ".......#...#....",
    ".......#...#....",
    "......#.....#...",
    "......##...##...",
]

# Zombie ON frame 4: walks back upright! (neverdie!)
ZOMBIE_ON_4 = [
    "......###.......",
    ".....#####......",
    ".....#####......",
    "......###.......",
    ".....#####......",
    "....#o####......",  # bullet hole remains
    ".....#####......",
    "......###.......",
    "......#.#.......",
    ".....#...#......",
    ".....#...#......",
    "....#.....#.....",
    "....##...##.....",
]

# ZombieSleep: slumped over, Z's
ZOMBIE_SLEEP = [
    ".........####...",  # Z (big, clear)
    "...........##...",
    "..........##....",
    ".........##.....",
    ".........####...",  # Z end
    "..........##....",  # z (small)
    ".........##.....",
    "....###..##.....",  # z end + head
    "...#####........",
    "...##o##........",  # head drooped
    "....###.........",
    "..#o###o#.......",  # torso with holes
    "..#..###........",
    "....####........",
    "..##....##......",  # legs folded
    "..##....##......",
]

# Wake transition frame 1: starting to lift head
ZOMBIE_WAKE_1 = [
    "................",
    "................",
    "....###.........",
    "...#####........",
    "...##o##........",
    "....###.........",
    "...#####........",
    "..#o###o#.......",
    "..#..###..#.....",  # arms starting to extend
    "....####........",
    "....#..#........",
    "...#....#.......",
    "...#....#.......",
    "...##..##.......",
]

# Wake transition frame 2: mostly upright
ZOMBIE_WAKE_2 = [
    "................",
    "......###.......",
    ".....#####......",
    ".....##o##......",
    "......###.......",
    ".....#####......",
    "....#o###o#.....",
    "...#..###..#....",
    "......###.......",
    "......#.#.......",
    ".....#...#......",
    ".....#...#......",
    "....#.....#.....",
    "....##...##.....",
]

# Sleep transition frame 1: starting to slump
ZOMBIE_SLEEP_TRANS_1 = [
    "................",
    ".....###........",
    "....#####.......",
    "....##o##.......",
    ".....###........",
    "....#####.......",
    "...#o###o#......",
    "..#..###........",
    ".....###........",
    ".....#.#........",
    "....#...#.......",
    "....#...#.......",
    "...#.....#......",
    "...##...##......",
]

# Sleep transition frame 2: more slumped
ZOMBIE_SLEEP_TRANS_2 = [
    "................",
    "................",
    "....###.........",
    "...#####........",
    "...##o##........",
    "....###.........",
    "...#####........",
    "..#o###o#.......",
    "..#..###........",
    "....####........",
    "....#..#........",
    "...#....#.......",
    "...#....#.......",
    "..##....##......",
]

# Sleep transition frame 3: fully slumped (same as sleep)
ZOMBIE_SLEEP_TRANS_3 = ZOMBIE_SLEEP

# Auto-off frame 1: zombie stumbles
ZOMBIE_AUTO_OFF_1 = [
    "......###.......",
    ".....#####......",
    ".....##o##......",
    "......###.......",
    ".....#####......",
    "....#o###o#.....",
    "...#..###.......",
    "......###.......",
    "......#.#.......",
    ".....#...#......",
    "....#.....#.....",
    "....##...##.....",
]

# Auto-off frame 2: falling
ZOMBIE_AUTO_OFF_2 = [
    "................",
    ".....###........",
    "....#####.......",
    "....##o##.......",
    ".....###........",
    "...#o####.......",
    "..#..###........",
    ".....###........",
    "....#..#........",
    "...#....#.......",
    "...##..##.......",
]

# Auto-off frame 3: almost down
ZOMBIE_AUTO_OFF_3 = [
    "................",
    "................",
    "...###..........",
    "..#####.........",
    "..##o###........",
    "...####.........",
    "..#o###o#.......",
    "..#..###........",
    "...####.........",
    "..##..##........",
    "..##..##........",
]

# Auto-off frame 4: collapsed (same as sleep)
ZOMBIE_AUTO_OFF_4 = ZOMBIE_SLEEP


def render_frame(bitmap, name):
    """Render a bitmap to 1x/2x PNGs using Contents.json filenames."""
    import json  # noqa: F811

    imageset_dir = ASSETS_BASE / f"{name}.imageset"
    contents_path = imageset_dir / "Contents.json"

    with open(contents_path) as f:
        contents = json.load(f)

    for entry in contents["images"]:
        filename = entry.get("filename")
        scale_str = entry.get("scale", "1x")
        if not filename:
            continue
        scale = int(scale_str.replace("x", ""))

        pair = create_image(scale)
        draw_bitmap(pair, bitmap, offset_x=1, offset_y=1)
        img = pair[0]

        filepath = imageset_dir / filename
        img.save(str(filepath), "PNG")
        print(f"  Saved {filepath.name}")


def main():
    frames = {
        "ZombieSleep": ZOMBIE_SLEEP,
        "ZombieOn_01": ZOMBIE_ON_1,
        "ZombieOn_02": ZOMBIE_ON_2,
        "ZombieOn_03": ZOMBIE_ON_3,
        "ZombieOn_04": ZOMBIE_ON_4,
        "ZombieWake_01": ZOMBIE_WAKE_1,
        "ZombieWake_02": ZOMBIE_WAKE_2,
        "ZombieSleepTrans_01": ZOMBIE_SLEEP_TRANS_1,
        "ZombieSleepTrans_02": ZOMBIE_SLEEP_TRANS_2,
        "ZombieSleepTrans_03": ZOMBIE_SLEEP_TRANS_3,
        "ZombieAutoOff_01": ZOMBIE_AUTO_OFF_1,
        "ZombieAutoOff_02": ZOMBIE_AUTO_OFF_2,
        "ZombieAutoOff_03": ZOMBIE_AUTO_OFF_3,
        "ZombieAutoOff_04": ZOMBIE_AUTO_OFF_4,
    }

    for name, bitmap in frames.items():
        print(f"Rendering {name}...")
        render_frame(bitmap, name)

    print(f"\nDone! Generated {len(frames)} icon sets ({len(frames) * 2} files)")


if __name__ == "__main__":
    main()
