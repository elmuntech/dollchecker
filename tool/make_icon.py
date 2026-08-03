#!/usr/bin/env python3
"""Generates the DollChecker app icon.

The stores will not accept a submission without an icon, and `flutter create`
ships Flutter's own. This draws ours from geometry — a teddy silhouette with a
safety check — so the repository carries a real, reproducible icon instead of a
placeholder someone has to remember to replace.

It is deliberately plain. If a designer produces something better, drop their
1024x1024 PNG over `app/assets/icon/app_icon.png` (and a transparent version
over `app_icon_foreground.png`) and this script is no longer needed.

Outputs:
  app/assets/icon/app_icon.png             1024x1024, full bleed  (iOS, legacy)
  app/assets/icon/app_icon_foreground.png  1024x1024, transparent (Android adaptive)
  docs/brand/app_icon.svg                  vector source, for editing

Usage:  python3 tool/make_icon.py
"""

from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path

SIZE = 1024
SUPERSAMPLE = 3  # 3x3 samples per pixel — enough to hide the stair-stepping.

BRAND = (0x4C, 0x6E, 0xF5)       # AppTheme.seed
BRAND_DEEP = (0x36, 0x4F, 0xC7)  # bottom of the background gradient
CREAM = (0xFF, 0xF6, 0xE9)       # the bear
CREAM_DARK = (0xE8, 0xD5, 0xBC)  # muzzle / inner ears
INK = (0x2A, 0x2F, 0x45)         # eyes
GREEN = (0x2E, 0x7D, 0x32)       # AppTheme.safetyGreen
WHITE = (0xFF, 0xFF, 0xFF)


# --- geometry -------------------------------------------------------------
# Every shape answers "is this point inside me?" for one sample. Slow, but the
# whole icon is a few million samples and it needs no dependencies.

def _circle(px: float, py: float, cx: float, cy: float, r: float) -> bool:
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def _rounded_square(px: float, py: float, size: float, radius: float) -> bool:
    x = min(px, size - px)
    y = min(py, size - py)
    if x >= radius or y >= radius:
        return x >= 0 and y >= 0
    return (radius - x) ** 2 + (radius - y) ** 2 <= radius * radius


def _segment(px: float, py: float, ax: float, ay: float, bx: float, by: float,
             half_width: float) -> bool:
    """A thick line segment with round caps — the two strokes of the check."""
    dx, dy = bx - ax, by - ay
    length_sq = dx * dx + dy * dy
    t = 0.0 if length_sq == 0 else ((px - ax) * dx + (py - ay) * dy) / length_sq
    t = max(0.0, min(1.0, t))
    nx, ny = ax + t * dx, ay + t * dy
    return (px - nx) ** 2 + (py - ny) ** 2 <= half_width * half_width


def _mix(bottom: tuple[int, int, int], top: tuple[int, int, int],
         amount: float) -> tuple[int, int, int]:
    return tuple(
        round(b + (t - b) * amount) for b, t in zip(bottom, top)
    )  # type: ignore[return-value]


def sample(x: float, y: float, *, background: bool) -> tuple[int, int, int, int]:
    """Colour of one sample point, painted back to front."""
    s = SIZE
    rgb: tuple[int, int, int] | None = None
    alpha = 0

    if background and _rounded_square(x, y, s, s * 0.2237):
        # Apple rounds the corners itself; a gentle vertical gradient keeps the
        # flat colour from looking dead at large sizes.
        rgb = _mix(BRAND, BRAND_DEEP, y / s)
        alpha = 255

    # Bear: head, ears, muzzle, eyes. Centred slightly high so the check badge
    # at the bottom right does not crowd it.
    cx, cy, head_r = s * 0.5, s * 0.47, s * 0.235
    ear_r = head_r * 0.42
    ear_dx, ear_dy = head_r * 0.82, head_r * 0.78

    for sign in (-1, 1):
        ex = cx + sign * ear_dx
        ey = cy - ear_dy
        if _circle(x, y, ex, ey, ear_r):
            rgb, alpha = CREAM, 255
        if _circle(x, y, ex, ey, ear_r * 0.5):
            rgb, alpha = CREAM_DARK, 255

    if _circle(x, y, cx, cy, head_r):
        rgb, alpha = CREAM, 255

        muzzle_cy = cy + head_r * 0.34
        if _circle(x, y, cx, muzzle_cy, head_r * 0.44):
            rgb = CREAM_DARK
        if _circle(x, y, cx, muzzle_cy - head_r * 0.13, head_r * 0.16):
            rgb = INK
        for sign in (-1, 1):
            if _circle(x, y, cx + sign * head_r * 0.36,
                       cy - head_r * 0.18, head_r * 0.11):
                rgb = INK

    # Safety check badge, overlapping the head's lower right.
    bx, by, badge_r = s * 0.735, s * 0.7, s * 0.155
    if _circle(x, y, bx, by, badge_r * 1.16):
        rgb, alpha = (_mix(BRAND, BRAND_DEEP, y / s) if background else WHITE), 255
    if _circle(x, y, bx, by, badge_r):
        rgb, alpha = GREEN, 255
    if _circle(x, y, bx, by, badge_r):
        stroke = badge_r * 0.155
        short = _segment(x, y, bx - badge_r * 0.45, by + badge_r * 0.02,
                         bx - badge_r * 0.1, by + badge_r * 0.4, stroke)
        long_ = _segment(x, y, bx - badge_r * 0.1, by + badge_r * 0.4,
                         bx + badge_r * 0.47, by - badge_r * 0.38, stroke)
        if short or long_:
            rgb = WHITE

    if rgb is None:
        return (0, 0, 0, 0)
    return (*rgb, alpha)


def render(background: bool, scale: float = 1.0) -> bytearray:
    """Renders the icon into raw RGBA rows.

    `scale` shrinks the artwork inside the canvas — Android's adaptive icon
    crops aggressively, so the foreground layer has to keep clear of the edges.
    """
    rows = bytearray()
    step = 1.0 / SUPERSAMPLE
    offset = step / 2
    samples = SUPERSAMPLE * SUPERSAMPLE
    centre = SIZE / 2

    for py in range(SIZE):
        rows.append(0)  # PNG filter byte: none
        row = bytearray()
        for px in range(SIZE):
            r = g = b = a = 0
            for sy in range(SUPERSAMPLE):
                for sx in range(SUPERSAMPLE):
                    x = px + offset + sx * step
                    y = py + offset + sy * step
                    if scale != 1.0:
                        x = centre + (x - centre) / scale
                        y = centre + (y - centre) / scale
                    sr, sg, sb, sa = sample(x, y, background=background)
                    # Premultiplied accumulation, so transparent samples do not
                    # drag the colour towards black at the edges.
                    r += sr * sa
                    g += sg * sa
                    b += sb * sa
                    a += sa
            if a == 0:
                row += bytes(4)
            else:
                row += bytes((r // a, g // a, b // a, a // samples))
        rows += row
    return rows


def write_png(path: Path, raw: bytes) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <!-- DollChecker app icon. Regenerate the PNGs with tool/make_icon.py, or
       replace both PNGs with a designer's artwork and drop this file. -->
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#4C6EF5"/>
      <stop offset="100%" stop-color="#364FC7"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="229" fill="url(#bg)"/>
  <g fill="#FFF6E9">
    <circle cx="315" cy="293" r="101"/>
    <circle cx="709" cy="293" r="101"/>
    <circle cx="512" cy="481" r="241"/>
  </g>
  <g fill="#E8D5BC">
    <circle cx="315" cy="293" r="50"/>
    <circle cx="709" cy="293" r="50"/>
    <circle cx="512" cy="563" r="106"/>
  </g>
  <g fill="#2A2F45">
    <circle cx="512" cy="532" r="39"/>
    <circle cx="427" cy="438" r="27"/>
    <circle cx="597" cy="438" r="27"/>
  </g>
  <circle cx="753" cy="717" r="184" fill="url(#bg)"/>
  <circle cx="753" cy="717" r="159" fill="#2E7D32"/>
  <path d="M681 720 L737 780 L828 658" fill="none" stroke="#FFFFFF"
        stroke-width="49" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    icons = root / "app/assets/icon"

    write_png(icons / "app_icon.png", render(background=True))
    # Android crops an adaptive icon to as little as 66% of the canvas.
    write_png(icons / "app_icon_foreground.png",
              render(background=False, scale=0.68))
    (root / "docs/brand").mkdir(parents=True, exist_ok=True)
    (root / "docs/brand/app_icon.svg").write_text(SVG)

    print("wrote app/assets/icon/app_icon.png,"
          " app/assets/icon/app_icon_foreground.png, docs/brand/app_icon.svg")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
