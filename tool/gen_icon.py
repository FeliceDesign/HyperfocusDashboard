#!/usr/bin/env python3
"""Erzeugt das Non-Finito-Launcher-Icon als PNG-Quellen für
flutter_launcher_icons.

Der Ring endet bei 78 %, davor drei Brüche, deren Abstand sich zum Abbruch
hin verkürzt (Variante C). Enden sind flach (stroke-linecap="butt"). Farben:
ink (#E8EBEE) auf bg (#101215), keine Kategorie-/Warnfarbe, kein Verlauf.
"""

import math
import os

from PIL import Image, ImageDraw

BG = (16, 18, 21, 255)       # #101215
INK = (232, 235, 238, 255)   # #E8EBEE

# Dash-Segmente (Startwinkel, Bogen) in Grad, ab -90° (oben), im Uhrzeigersinn.
# Entspricht stroke-dasharray "110 5 36 5 17 5 8.2 52.56" bei Umfang 238.76.
SEGMENTS = [
    (-90.0, 165.87),
    (83.41, 54.28),
    (145.23, 25.63),
    (178.40, 12.36),
]

SUPERSAMPLE = 4


def draw_ring(size, r_frac, sw_frac, background):
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), background)
    draw = ImageDraw.Draw(img)
    r = s * r_frac
    sw = max(1, int(round(s * sw_frac)))
    c = s / 2
    box = [c - r, c - r, c + r, c + r]
    for start, sweep in SEGMENTS:
        draw.arc(box, start, start + sweep, fill=INK, width=sw)
    return img.resize((size, size), Image.LANCZOS)


def main():
    out = "assets/icon"
    os.makedirs(out, exist_ok=True)
    # Vollicon: gefüllter Hintergrund, Ring nahe am Rand.
    draw_ring(1024, 0.38, 0.09, BG).save(os.path.join(out, "icon.png"))
    # Adaptiver Vordergrund: transparent, Ring in der Safe-Zone (kleiner).
    draw_ring(1024, 0.30, 0.072, (0, 0, 0, 0)).save(
        os.path.join(out, "icon_foreground.png"))
    print("Non Finito icons written to", out)


if __name__ == "__main__":
    main()
