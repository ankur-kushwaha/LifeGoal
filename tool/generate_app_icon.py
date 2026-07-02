#!/usr/bin/env python3
"""Generate LifeGoal AI launcher icon (1024x1024 PNG)."""
from PIL import Image, ImageDraw

SIZE = 1024
BRAND_GREEN = (0, 163, 123)  # #00A37B
WHITE = (255, 255, 255)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Rounded square background (iOS/Android safe zone)
margin = 0
radius = 220
draw.rounded_rectangle(
    [margin, margin, SIZE - margin, SIZE - margin],
    radius=radius,
    fill=BRAND_GREEN,
)

cx, cy = SIZE // 2, SIZE // 2

# Outer target ring
draw.ellipse([cx - 300, cy - 300, cx + 300, cy + 300], outline=WHITE, width=36)

# Middle ring
draw.ellipse([cx - 190, cy - 190, cx + 190, cy + 190], outline=WHITE, width=32)

# Inner filled circle (bullseye)
draw.ellipse([cx - 80, cy - 80, cx + 80, cy + 80], fill=WHITE)

# Upward growth arrow (financial progress)
arrow_color = BRAND_GREEN
points = [
    (cx + 200, cy + 60),
    (cx + 200, cy - 140),
    (cx + 150, cy - 90),
    (cx + 120, cy - 160),
    (cx + 280, cy - 160),
    (cx + 250, cy - 90),
    (cx + 250, cy + 60),
]
draw.polygon(points, fill=arrow_color)

out = "assets/icon/app_icon.png"
img.save(out, "PNG")
print(f"Saved {out} ({SIZE}x{SIZE})")
