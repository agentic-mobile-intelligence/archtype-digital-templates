#!/usr/bin/env python3
"""
generate-cards.py — Social media card generator for ai-architecture-books series.

Generates:
  content/social/card-og.png       1200×630  (Twitter/X, LinkedIn, OpenGraph)
  content/social/card-square.png   1080×1080 (Instagram, threads)

Usage (run from book root):
  python3 content/scripts/generate-cards.py

Requirements: pip3 install Pillow
"""

import os
import sys
import textwrap
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("ERROR: Pillow not installed. Run: pip3 install Pillow")
    sys.exit(1)

# ── Book root resolution ──────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
BOOK_ROOT = SCRIPT_DIR.parent.parent   # content/scripts/ → content/ → book root
META_FILE = BOOK_ROOT / "publishing" / "metadata.yaml"
OUT_DIR   = BOOK_ROOT / "content" / "social"

# ── Color palette (matches eisvogel titlepage config) ─────────────────────────
BG         = "#1A1A2E"   # deep navy
ACCENT     = "#4A90D9"   # electric blue
TEXT_HEAD  = "#EEEEEE"   # near white
TEXT_BODY  = "#A8B8D0"   # muted blue-grey
TEXT_DIM   = "#5B6E8A"   # dim blue-grey
RULE_COLOR = "#4A90D9"
BADGE_BG   = "#0D1B35"   # slightly darker than BG

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

# ── Font resolution ───────────────────────────────────────────────────────────
FONT_DIRS = [
    Path("/Users") / os.environ.get("USER", "jay") / "Library" / "Fonts",
    Path("/System/Library/Fonts"),
    Path("/Library/Fonts"),
]

def find_font(names):
    """Return path to first font found matching any of the given filenames."""
    for d in FONT_DIRS:
        for name in names:
            p = d / name
            if p.exists():
                return str(p)
    return None

FONT_BOLD    = find_font(["GlacialIndifference-Bold.otf", "SFNS.ttf"])
FONT_REGULAR = find_font(["GlacialIndifference-Regular.otf", "SFNS.ttf"])
FONT_SERIF   = find_font(["NewYork.ttf", "Georgia.ttf"])
FONT_MONO    = find_font(["SFNSMono.ttf", "Monaco.ttf"])

def load_font(path, size):
    if path:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()

# ── Metadata reader ───────────────────────────────────────────────────────────
def read_metadata():
    if not META_FILE.exists():
        print(f"WARNING: metadata.yaml not found at {META_FILE}")
        return {}
    text = META_FILE.read_text()
    meta = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("title:"):
            meta["title"] = line[6:].strip().strip('"')
        elif line.startswith("subtitle:"):
            meta["subtitle"] = line[9:].strip().strip('"')
        elif line.startswith("date:"):
            meta["date"] = line[5:].strip().strip('"')
        elif "Jay Elizaga" in line and "name:" in line:
            meta["author"] = "Jay Elizaga"
    meta.setdefault("title", BOOK_ROOT.name)
    meta.setdefault("subtitle", "Agentic Era Series")
    meta.setdefault("author", "Jay Elizaga")
    meta.setdefault("date", "2026")
    # Clean subtitle: strip the trailing "— Pre-Release Preprint"
    sub = meta["subtitle"]
    for suffix in [" — Pre-Release Preprint", " — Preprint", "— Pre-Release Preprint"]:
        if sub.endswith(suffix):
            sub = sub[: -len(suffix)].rstrip()
            break
    meta["subtitle_clean"] = sub
    return meta

# ── Drawing helpers ───────────────────────────────────────────────────────────
def draw_multiline(draw, text, x, y, font, fill, max_width, line_spacing=1.25):
    """Word-wrap text and draw it. Returns the y after the last line."""
    words = text.split()
    lines = []
    current = []
    for word in words:
        test = " ".join(current + [word])
        bbox = font.getbbox(test)
        w = bbox[2] - bbox[0]
        if w > max_width and current:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))

    line_h = font.getbbox("Ag")[3] - font.getbbox("Ag")[1]
    step = int(line_h * line_spacing)
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        y += step
    return y

def draw_badge(draw, text, x, y, font, bg_color, text_color, pad_x=18, pad_h=8):
    """Draw a rounded-rectangle badge. Returns (x2, y2)."""
    bbox = font.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    bw = tw + 2 * pad_x
    bh = th + 2 * pad_h
    r = bh // 2
    draw.rounded_rectangle([x, y, x + bw, y + bh], radius=r, fill=hex_to_rgb(bg_color))
    draw.text((x + pad_x, y + pad_h), text, font=font, fill=hex_to_rgb(text_color))
    return x + bw, y + bh

# ── Card: OG / Twitter (1200×630) ─────────────────────────────────────────────
def make_og_card(meta, out_path):
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), hex_to_rgb(BG))
    draw = ImageDraw.Draw(img)

    MARGIN_L = 80
    MARGIN_R = 80
    USABLE_W = W - MARGIN_L - MARGIN_R - 6  # 6 = accent bar

    # Left accent bar
    BAR_W = 6
    draw.rectangle([0, 0, BAR_W - 1, H], fill=hex_to_rgb(ACCENT))

    X = MARGIN_L + BAR_W

    # Top badge row
    badge_font = load_font(FONT_BOLD, 17)
    badge_y = 52
    bx2, _ = draw_badge(draw, "AGENTIC ERA SERIES", X, badge_y, badge_font,
                        BADGE_BG, ACCENT, pad_x=16, pad_h=6)
    bx2 += 14
    draw_badge(draw, "PRE-RELEASE", bx2, badge_y, badge_font,
               BADGE_BG, TEXT_DIM, pad_x=16, pad_h=6)

    # Title
    title_font_size = 64 if len(meta["title"]) < 40 else (52 if len(meta["title"]) < 60 else 44)
    title_font = load_font(FONT_BOLD, title_font_size)
    title_y = 132
    title_y_end = draw_multiline(draw, meta["title"], X, title_y, title_font,
                                  hex_to_rgb(TEXT_HEAD), USABLE_W, line_spacing=1.15)

    # Rule
    rule_y = title_y_end + 20
    draw.rectangle([X, rule_y, X + 64, rule_y + 3], fill=hex_to_rgb(ACCENT))

    # Subtitle
    sub_font = load_font(FONT_REGULAR, 22)
    sub_y = rule_y + 22
    sub_y_end = draw_multiline(draw, meta["subtitle_clean"], X, sub_y, sub_font,
                                hex_to_rgb(TEXT_BODY), USABLE_W, line_spacing=1.4)

    # Footer rule
    footer_rule_y = H - 80
    draw.rectangle([X, footer_rule_y, W - MARGIN_R, footer_rule_y + 1],
                   fill=hex_to_rgb(TEXT_DIM))

    # Footer: author left, domain right
    foot_font = load_font(FONT_BOLD, 18)
    draw.text((X, footer_rule_y + 14), meta["author"],
              font=foot_font, fill=hex_to_rgb(TEXT_BODY))
    domain = "elizaga.dev"
    dom_bbox = foot_font.getbbox(domain)
    dom_w = dom_bbox[2] - dom_bbox[0]
    draw.text((W - MARGIN_R - dom_w, footer_rule_y + 14), domain,
              font=foot_font, fill=hex_to_rgb(ACCENT))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", dpi=(300, 300))
    print(f"  [OG]     {out_path.name}  {W}×{H}")

# ── Card: Square (1080×1080) ──────────────────────────────────────────────────
def make_square_card(meta, out_path):
    W, H = 1080, 1080
    img = Image.new("RGB", (W, H), hex_to_rgb(BG))
    draw = ImageDraw.Draw(img)

    # Top stripe
    STRIPE_H = 8
    draw.rectangle([0, 0, W, STRIPE_H - 1], fill=hex_to_rgb(ACCENT))

    PAD = 80

    # Series badge — centered
    badge_font = load_font(FONT_BOLD, 18)
    badge_text = "AGENTIC ERA SERIES"
    btw = badge_font.getbbox(badge_text)[2]
    bx = (W - btw - 32) // 2
    draw_badge(draw, badge_text, bx, PAD + 24, badge_font,
               BADGE_BG, ACCENT, pad_x=16, pad_h=7)

    # Large centered title
    title_font_size = 72 if len(meta["title"]) < 30 else (60 if len(meta["title"]) < 50 else 48)
    title_font = load_font(FONT_BOLD, title_font_size)
    MAX_W = W - 2 * PAD
    # Word-wrap to get lines
    words = meta["title"].split()
    lines, cur = [], []
    for word in words:
        test = " ".join(cur + [word])
        tw = title_font.getbbox(test)[2]
        if tw > MAX_W and cur:
            lines.append(" ".join(cur)); cur = [word]
        else:
            cur.append(word)
    if cur: lines.append(" ".join(cur))

    line_h = title_font.getbbox("Ag")[3]
    line_step = int(line_h * 1.15)
    title_block_h = len(lines) * line_step
    title_start_y = (H // 2) - (title_block_h // 2) - 60

    for i, line in enumerate(lines):
        lw = title_font.getbbox(line)[2]
        draw.text(((W - lw) // 2, title_start_y + i * line_step), line,
                  font=title_font, fill=hex_to_rgb(TEXT_HEAD))

    # Center accent rule
    rule_y = title_start_y + title_block_h + 28
    draw.rectangle([(W - 80) // 2, rule_y, (W + 80) // 2, rule_y + 4],
                   fill=hex_to_rgb(ACCENT))

    # Subtitle centered
    sub_font = load_font(FONT_REGULAR, 24)
    sub_y = rule_y + 24
    sub_words = meta["subtitle_clean"].split()
    sub_lines, cur = [], []
    for word in sub_words:
        test = " ".join(cur + [word])
        if sub_font.getbbox(test)[2] > MAX_W and cur:
            sub_lines.append(" ".join(cur)); cur = [word]
        else:
            cur.append(word)
    if cur: sub_lines.append(" ".join(cur))

    sub_lh = sub_font.getbbox("Ag")[3]
    for i, line in enumerate(sub_lines):
        lw = sub_font.getbbox(line)[2]
        draw.text(((W - lw) // 2, sub_y + i * int(sub_lh * 1.4)), line,
                  font=sub_font, fill=hex_to_rgb(TEXT_BODY))

    # Bottom footer
    BOTTOM_PAD = 60
    foot_font = load_font(FONT_BOLD, 20)
    author_text = meta["author"] + "  ·  elizaga.dev"
    aw = foot_font.getbbox(author_text)[2]
    draw.text(((W - aw) // 2, H - BOTTOM_PAD - 20), author_text,
              font=foot_font, fill=hex_to_rgb(TEXT_DIM))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", dpi=(300, 300))
    print(f"  [Square] {out_path.name}  {W}×{H}")

# ── Card: Thread/Story teaser (1080×566, Twitter card) ───────────────────────
def make_thread_card(meta, out_path):
    """Minimal card with a hook phrase for Twitter threads."""
    W, H = 1080, 566
    img = Image.new("RGB", (W, H), hex_to_rgb(BG))
    draw = ImageDraw.Draw(img)

    PAD = 72
    USABLE = W - 2 * PAD

    # Subtle grid pattern
    for gx in range(0, W, 60):
        draw.rectangle([gx, 0, gx, H], fill=(*hex_to_rgb("#1F2D45"), 80))
    for gy in range(0, H, 60):
        draw.rectangle([0, gy, W, gy], fill=(*hex_to_rgb("#1F2D45"), 80))

    # Accent bar top
    draw.rectangle([0, 0, W, 5], fill=hex_to_rgb(ACCENT))

    # Book number / series
    label_font = load_font(FONT_MONO, 14)
    series_text = "elizaga.dev  ·  agentic era series  ·  pre-release"
    draw.text((PAD, PAD), series_text, font=label_font, fill=hex_to_rgb(TEXT_DIM))

    # Big title
    title_font = load_font(FONT_BOLD, 56 if len(meta["title"]) < 40 else 44)
    title_y = PAD + 48
    draw_multiline(draw, meta["title"], PAD, title_y, title_font,
                   hex_to_rgb(TEXT_HEAD), USABLE, line_spacing=1.18)

    # Bottom hook
    hook_font = load_font(FONT_REGULAR, 21)
    hook = meta["subtitle_clean"]
    if len(hook) > 80:
        hook = hook[:78].rsplit(" ", 1)[0] + "…"
    draw.text((PAD, H - PAD - 30), hook, font=hook_font, fill=hex_to_rgb(TEXT_BODY))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", dpi=(300, 300))
    print(f"  [Thread] {out_path.name}  {W}×{H}")

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    meta = read_metadata()
    print(f"\n{meta['title']}")
    print(f"  Root: {BOOK_ROOT}")

    make_og_card(meta,      OUT_DIR / "card-og.png")
    make_square_card(meta,  OUT_DIR / "card-square.png")
    make_thread_card(meta,  OUT_DIR / "card-thread.png")
    print(f"  → {OUT_DIR}/")

if __name__ == "__main__":
    main()
