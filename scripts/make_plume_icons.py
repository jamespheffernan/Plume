#!/usr/bin/env python3
"""Generate Plume app icons: a single calm plume (feather) mark in ink on paper.

Drawn as vector-style geometry at 4x and downsampled for smooth edges. One
1024x1024 PNG per colour scheme, written into the asset catalog in place.
"""
import math
from PIL import Image, ImageDraw

SS = 4                      # supersample factor
OUT = 1024
W = OUT * SS                # working canvas

# (paper, ink) per scheme — matches Theme.swift
SCHEMES = {
    "BreatheClock/Resources/Assets.xcassets/AppIcon.appiconset/BreatheClockIcon.png":
        ((0xF1, 0xEA, 0xD8), (0x2E, 0x2A, 0x25)),   # Newsprint
    "BreatheClock/Resources/Assets.xcassets/SageAppIcon.appiconset/SageAppIcon.png":
        ((0xE7, 0xE6, 0xD2), (0x34, 0x42, 0x3A)),   # Sage
    "BreatheClock/Resources/Assets.xcassets/IndigoAppIcon.appiconset/IndigoAppIcon.png":
        ((0xE7, 0xE0, 0xCC), (0x22, 0x2D, 0x49)),   # Evening
}

# Shaft as a cubic Bézier, base (bottom) -> tip (top), gently curved.
P0 = (W * 0.520, W * 0.860)   # quill base, just right of centre
P1 = (W * 0.585, W * 0.575)
P2 = (W * 0.455, W * 0.300)
P3 = (W * 0.430, W * 0.110)   # tip, just left of centre

VANE_START = 0.13             # below this t the shaft is a bare quill
WMAX = W * 0.166              # max half-width of the vane


def bez(t, a, b, c, d):
    mt = 1 - t
    return (mt**3 * a[0] + 3 * mt**2 * t * b[0] + 3 * mt * t**2 * c[0] + t**3 * d[0],
            mt**3 * a[1] + 3 * mt**2 * t * b[1] + 3 * mt * t**2 * c[1] + t**3 * d[1])


def dbez(t, a, b, c, d):
    mt = 1 - t
    return (3 * mt**2 * (b[0] - a[0]) + 6 * mt * t * (c[0] - b[0]) + 3 * t**2 * (d[0] - c[0]),
            3 * mt**2 * (b[1] - a[1]) + 6 * mt * t * (c[1] - b[1]) + 3 * t**2 * (d[1] - c[1]))


def shaft(t):
    return bez(t, P0, P1, P2, P3)


def normal(t):
    dx, dy = dbez(t, P0, P1, P2, P3)
    n = math.hypot(dx, dy) or 1.0
    return (-dy / n, dx / n)


def half_width(t):
    """Feather vane: zero at base/tip, widest a little past the middle."""
    if t <= VANE_START:
        return 0.0
    u = (t - VANE_START) / (1 - VANE_START)
    return WMAX * (math.sin(math.pi * u) ** 0.72)


def offset_polygon(t0, t1, hw, steps=240):
    left, right = [], []
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        cx, cy = shaft(t)
        nx, ny = normal(t)
        w = hw(t)
        left.append((cx + nx * w, cy + ny * w))
        right.append((cx - nx * w, cy - ny * w))
    return left + right[::-1]


def render(paper, ink):
    img = Image.new("RGB", (W, W), paper)
    d = ImageDraw.Draw(img)

    # Quill: a slim tapering line from the base up to where the vane begins.
    def quill_hw(t):
        u = t / VANE_START
        return W * 0.010 * (0.4 + 0.6 * u)
    d.polygon(offset_polygon(0.0, VANE_START + 0.005, quill_hw, steps=80), fill=ink)

    # Vane: the feather body.
    d.polygon(offset_polygon(VANE_START, 1.0, half_width), fill=ink)

    # Rachis: a fine paper-coloured split down the centre of the vane.
    def rachis_hw(t):
        if t <= VANE_START:
            return 0.0
        u = (t - VANE_START) / (1 - VANE_START)
        return W * 0.012 * (1 - u) ** 1.3
    d.polygon(offset_polygon(VANE_START, 0.985, rachis_hw), fill=paper)

    # Barb slits: a few thin paper-coloured gaps fanning toward the tip.
    n_barbs = 9
    for i in range(n_barbs):
        t = VANE_START + (0.86 - VANE_START) * (i + 0.5) / n_barbs
        cx, cy = shaft(t)
        nx, ny = normal(t)
        tx, ty = dbez(t, P0, P1, P2, P3)
        tl = math.hypot(tx, ty) or 1.0
        tx, ty = tx / tl, ty / tl
        w = half_width(t)
        inner = 0.16
        for side in (1, -1):
            sx = cx + nx * w * inner * side
            sy = cy + ny * w * inner * side
            # angle the slit outward and toward the tip
            ex = cx + (nx * side * 0.92 + tx * 0.5) * w * 0.92
            ey = cy + (ny * side * 0.92 + ty * 0.5) * w * 0.92
            d.line([(sx, sy), (ex, ey)], fill=paper, width=int(W * 0.006))

    return img.resize((OUT, OUT), Image.LANCZOS)


if __name__ == "__main__":
    for path, (paper, ink) in SCHEMES.items():
        render(paper, ink).save(path)
        print("wrote", path)
