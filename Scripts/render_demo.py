"""Assemble the demo using the ordered regions saved by the native iOS converter.

Requires Pillow. No panel detection or manually entered cropping coordinates here.
"""
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEMO = ROOT / 'Docs/demo'
page = json.loads((DEMO / 'conversion.json').read_text())['page']
source = Image.open(DEMO / 'source-page.png').convert('RGB')
assert source.size == (page['width'], page['height'])
w, h = source.size
width = 900
panels = []
for panel in page['panels']:
    r = panel['rect']
    box = (max(0, math.floor(r['x'] * w)), max(0, math.floor(r['y'] * h)),
           min(w, math.ceil((r['x'] + r['width']) * w)),
           min(h, math.ceil((r['y'] + r['height']) * h)))
    cropped = source.crop(box)
    contour = panel.get('contour')
    if contour and len(contour['points']) >= 3:
        mask = Image.new('L', source.size, 0)
        draw = ImageDraw.Draw(mask)
        draw.polygon([(p['x'] * w, p['y'] * h) for p in contour['points']], fill=255)
        for rect in contour.get('protectedRects', []):
            draw.rectangle((rect['x'] * w, rect['y'] * h,
                            (rect['x'] + rect['width']) * w,
                            (rect['y'] + rect['height']) * h), fill=255)
        masked = Image.new('RGB', cropped.size, 'black')
        masked.paste(cropped, (0, 0), mask.crop(box))
        cropped = masked
    # Match the reader's layout: full width, preserve each region's source aspect ratio.
    height = max(1, round(width * h * r['height'] / (w * r['width'])))
    panels.append(cropped.resize((width, height), Image.Resampling.LANCZOS))
strip = Image.new('RGB', (width, sum(p.height for p in panels)), 'black')
y = 0
for panel in panels:
    strip.paste(panel, (0, y))
    y += panel.height
strip.save(DEMO / 'vertical-page.png', optimize=True)
print(f'{len(panels)} ordered panels → {strip.width}×{strip.height} pixels')
