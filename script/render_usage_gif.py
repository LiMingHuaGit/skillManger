#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "readme" / "software-usage.gif"
W, H = 960, 540
FPS_MS = 70


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except Exception:
            continue
    return ImageFont.load_default()


F_TITLE = font(28, "bold")
F_HEAD = font(18, "bold")
F_BODY = font(15)
F_SMALL = font(12)
F_MONO = font(13)


COLORS = {
    "bg": (246, 247, 242),
    "paper": (255, 255, 253),
    "ink": (16, 17, 21),
    "muted": (103, 103, 111),
    "line": (224, 224, 216),
    "soft": (241, 241, 236),
    "green": (220, 238, 177),
    "mint": (200, 230, 205),
    "purple": (197, 176, 244),
    "coral": (243, 201, 182),
    "teal": (15, 118, 110),
    "black": (11, 11, 13),
}


def ease(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def rounded(draw: ImageDraw.ImageDraw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def shadowed_card(img: Image.Image, box, radius=16, fill=None, outline=None, shadow=18):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((x0, y0 + 10, x1, y1 + 10), radius=radius, fill=(0, 0, 0, 30))
    layer = layer.filter(ImageFilter.GaussianBlur(shadow))
    img.alpha_composite(layer)
    draw = ImageDraw.Draw(img)
    rounded(draw, box, radius, fill or COLORS["paper"], outline or COLORS["line"])


def text(draw, xy, value, fill=None, fnt=None, anchor=None):
    draw.text(xy, value, fill=fill or COLORS["ink"], font=fnt or F_BODY, anchor=anchor)


def base_frame(step: int, total: int) -> Image.Image:
    img = Image.new("RGBA", (W, H), COLORS["bg"] + (255,))
    draw = ImageDraw.Draw(img)
    draw.polygon([(0, 420), (150, 386), (265, 435), (390, 394), (580, 430), (728, 395), (960, 428), (960, 540), (0, 540)], fill=COLORS["green"])
    draw.polygon([(690, 0), (960, 0), (960, 128), (870, 88), (820, 36)], fill=COLORS["purple"])
    draw.rectangle((0, 0, W, 12), fill=(255, 255, 255, 140))
    text(draw, (34, 34), "Skill Manager", fnt=F_TITLE)
    text(draw, (34, 68), "Search -> manage -> note", fill=COLORS["muted"], fnt=F_BODY)
    progress_x = 34
    labels = ["Quick search", "Main panel", "Note capture"]
    active = 0 if step < total * 0.36 else 1 if step < total * 0.66 else 2
    for i, label in enumerate(labels):
        fill = COLORS["black"] if i == active else (255, 255, 255)
        ink = (255, 255, 255) if i == active else COLORS["ink"]
        rounded(draw, (progress_x, 478, progress_x + 132, 510), 16, fill, COLORS["black"])
        text(draw, (progress_x + 18, 488), label, fill=ink, fnt=F_SMALL)
        progress_x += 146
    return img


def draw_notch(img: Image.Image, frame: int, total: int):
    draw = ImageDraw.Draw(img)
    cx = W // 2
    y = 20
    rounded(draw, (cx - 126, y, cx + 126, y + 34), 17, COLORS["black"])
    text(draw, (cx - 72, y + 10), "skills", fill=(255, 255, 255), fnt=F_SMALL)
    text(draw, (cx - 16, y + 10), "notes", fill=(210, 210, 210), fnt=F_SMALL)
    text(draw, (cx + 42, y + 10), "files", fill=(210, 210, 210), fnt=F_SMALL)

    grow = ease(min(frame / 16, 1))
    panel_w = int(440 + 180 * grow)
    panel_h = int(96 + 268 * grow)
    x0 = cx - panel_w // 2
    y0 = 68
    shadowed_card(img, (x0, y0, x0 + panel_w, y0 + panel_h), radius=26, fill=(18, 18, 20), outline=(55, 55, 60), shadow=20)
    draw = ImageDraw.Draw(img)
    text(draw, (x0 + 24, y0 + 22), "Skill Quick Access", fill=(255, 255, 255), fnt=F_HEAD)
    text(draw, (x0 + 24, y0 + 47), "Search local, system, project, and plugin skills", fill=(188, 190, 196), fnt=F_SMALL)
    rounded(draw, (x0 + 24, y0 + 78, x0 + panel_w - 24, y0 + 116), 11, (36, 36, 40), (78, 78, 84))
    query = "imagegen"[: max(0, min(8, frame - 6))]
    text(draw, (x0 + 42, y0 + 90), "search  " + query, fill=(235, 235, 238), fnt=F_BODY)
    if frame % 8 < 4 and len(query) < 8:
        tx = x0 + 42 + draw.textlength("search  " + query, font=F_BODY) + 2
        draw.line((tx, y0 + 90, tx, y0 + 108), fill=(235, 235, 238), width=2)

    rows = [
        ("imagegen", "Generate raster visuals", COLORS["green"]),
        ("ming-gemini-image", "Gemini image assets", COLORS["purple"]),
        ("beautify-github-readme", "README hero and motion", COLORS["coral"]),
        ("playwright", "Browser screenshots", COLORS["mint"]),
    ]
    for i, (name, desc, color) in enumerate(rows):
        yy = y0 + 136 + i * 49
        alpha = 1 if frame > 10 + i * 2 else 0.25
        rounded(draw, (x0 + 24, yy, x0 + panel_w - 24, yy + 40), 10, (31, 31, 35), (60, 60, 66))
        rounded(draw, (x0 + 36, yy + 10, x0 + 52, yy + 26), 5, color)
        text(draw, (x0 + 62, yy + 8), name, fill=(255, 255, 255), fnt=F_SMALL)
        text(draw, (x0 + 62, yy + 23), desc, fill=(166, 168, 174), fnt=F_SMALL)


def draw_library(img: Image.Image, frame: int):
    draw = ImageDraw.Draw(img)
    t = ease((frame - 24) / 16)
    x = int(980 - 842 * t)
    y = 104
    shadowed_card(img, (x, y, x + 790, y + 348), radius=18, fill=COLORS["paper"], outline=COLORS["line"], shadow=18)
    draw = ImageDraw.Draw(img)
    rounded(draw, (x, y, x + 170, y + 348), 18, (248, 248, 244), COLORS["line"])
    text(draw, (x + 26, y + 26), "Focused Library", fnt=F_HEAD)
    nav = [("All skills", True), ("Recommendations", False), ("Plugins", False), ("Favorites", False), ("Settings", False)]
    for i, (label, active) in enumerate(nav):
        yy = y + 68 + i * 40
        if active:
            rounded(draw, (x + 18, yy - 8, x + 150, yy + 22), 9, COLORS["black"])
        text(draw, (x + 32, yy), label, fill=(255, 255, 255) if active else COLORS["muted"], fnt=F_SMALL)
    rounded(draw, (x + 192, y + 24, x + 528, y + 58), 10, COLORS["soft"], COLORS["line"])
    query = "source"[: max(0, min(6, frame - 33))]
    text(draw, (x + 210, y + 33), "Search name, tag, use case, or path  " + query, fill=COLORS["muted"], fnt=F_SMALL)
    rounded(draw, (x + 548, y + 24, x + 672, y + 58), 10, (255, 255, 255), COLORS["line"])
    text(draw, (x + 568, y + 33), "Local", fnt=F_SMALL)
    rows = [
        ("ming-skill-source-manager", "healthy", COLORS["green"]),
        ("skill-installer", "system", COLORS["purple"]),
        ("openai-docs", "plugin", COLORS["mint"]),
        ("build-run-debug", "plugin", COLORS["coral"]),
    ]
    for i, (name, status, color) in enumerate(rows):
        yy = y + 86 + i * 54
        rounded(draw, (x + 192, yy, x + 480, yy + 43), 10, (255, 255, 255), COLORS["line"])
        rounded(draw, (x + 206, yy + 12, x + 224, yy + 30), 6, color)
        text(draw, (x + 236, yy + 9), name, fnt=F_SMALL)
        text(draw, (x + 236, yy + 24), status, fill=COLORS["muted"], fnt=F_SMALL)
    rounded(draw, (x + 510, y + 86, x + 756, y + 294), 14, (255, 255, 255), COLORS["line"])
    text(draw, (x + 532, y + 112), "Skill detail", fnt=F_HEAD)
    text(draw, (x + 532, y + 142), "$ming-skill-source-manager", fnt=F_BODY)
    text(draw, (x + 532, y + 171), "Provenance audit", fill=COLORS["muted"], fnt=F_SMALL)
    text(draw, (x + 532, y + 197), "[$skill_name]($skill_path)", fill=COLORS["teal"], fnt=F_MONO)
    rounded(draw, (x + 532, y + 232, x + 662, y + 266), 12, COLORS["black"])
    text(draw, (x + 555, y + 241), "Copy mention", fill=(255, 255, 255), fnt=F_SMALL)


def draw_notes(img: Image.Image, frame: int):
    draw = ImageDraw.Draw(img)
    t = ease((frame - 48) / 15)
    x0 = 218
    y0 = int(566 - 428 * t)
    shadowed_card(img, (x0, y0, x0 + 524, y0 + 330), radius=26, fill=(18, 18, 20), outline=(55, 55, 60), shadow=20)
    draw = ImageDraw.Draw(img)
    text(draw, (x0 + 24, y0 + 24), "Quick Notes", fill=(255, 255, 255), fnt=F_HEAD)
    tabs = [("Skills", False), ("Notes", True), ("Shelf", False)]
    for i, (label, active) in enumerate(tabs):
        xx = x0 + 284 + i * 70
        rounded(draw, (xx, y0 + 20, xx + 58, y0 + 46), 13, COLORS["green"] if active else (38, 38, 42))
        text(draw, (xx + 14, y0 + 27), label, fill=COLORS["ink"] if active else (220, 220, 224), fnt=F_SMALL)
    rounded(draw, (x0 + 24, y0 + 66, x0 + 500, y0 + 292), 14, (249, 249, 245), (70, 70, 76))
    note = "# Release notes\n- verify skill search\n- keep source paths clean\n- copy handoff into chat"
    n = max(0, min(len(note), int((frame - 56) * 5.8)))
    yy = y0 + 90
    for line in note[:n].split("\n"):
        fill = COLORS["teal"] if line.startswith("#") else COLORS["ink"]
        fnt = F_HEAD if line.startswith("#") else F_BODY
        text(draw, (x0 + 50, yy), line, fill=fill, fnt=fnt)
        yy += 32
    if frame % 8 < 4:
        last = note[:n].split("\n")[-1] if n else ""
        cx = x0 + 50 + int(draw.textlength(last, font=F_BODY))
        draw.line((cx, yy - 30, cx, yy - 10), fill=COLORS["ink"], width=2)
    rounded(draw, (x0 + 338, y0 + 248, x0 + 478, y0 + 276), 14, COLORS["black"])
    text(draw, (x0 + 358, y0 + 255), "Saved locally", fill=(255, 255, 255), fnt=F_SMALL)


def render() -> None:
    total = 78
    frames = []
    for i in range(total):
        img = base_frame(i, total)
        if i < 34:
            draw_notch(img, i, total)
        elif i < 55:
            draw_notch(img, 28, total)
            draw_library(img, i)
        else:
            draw_library(img, 54)
            draw_notes(img, i)
        frames.append(img.convert("P", palette=Image.Palette.ADAPTIVE, colors=128))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        OUT,
        save_all=True,
        append_images=frames[1:],
        duration=FPS_MS,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(OUT)


if __name__ == "__main__":
    render()
