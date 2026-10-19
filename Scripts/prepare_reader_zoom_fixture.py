"""Prepare opt-in simulator UI fixture for inline zoom. Requires Pillow.
Usage: python3 Scripts/prepare_reader_zoom_fixture.py SIMULATOR_UUID
Only writes a synthetic chapter into the simulator's debug app container.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json
import re
import subprocess
import sys
import time
import uuid

sim = sys.argv[1]
subprocess.run(['xcrun', 'simctl', 'terminate', sim, 'fr.yannick.mangaflow'], capture_output=True)
data = subprocess.run(['xcrun', 'simctl', 'get_app_container', sim, 'fr.yannick.mangaflow', 'data'], capture_output=True, text=True, check=True).stdout.strip()
marker = Path('/tmp/mangaflow-panel-zoom-review.json')
root = Path(data) / 'Library/Application Support/MangaFlow'
if marker.exists():
    import shutil
    old = json.loads(marker.read_text())
    old_id = str(uuid.UUID(old['id'])).upper()
    shutil.rmtree(root / old_id, ignore_errors=True)
chapter_id = str(uuid.uuid4()).upper()
folder = root / chapter_id
folder.mkdir(parents=True)
image = Image.new('RGB', (800, 1200), 'white')
draw = ImageDraw.Draw(image)
rects = [(.02, .02, .44, .4), (.54, .02, .44, .4), (.02, .46, .96, .52)]
for (x, y, w, h), color in zip(rects, ['#c14343', '#42ac65', '#4568b6']):
    draw.rectangle((x * 800, y * 1200, (x + w) * 800, (y + h) * 1200), fill=color, outline='black', width=4)
draw.ellipse((520, 65, 690, 250), fill='white', outline='black', width=4)
draw.text((555, 140), 'HELLO', fill='black')
draw.text((50, 700), 'FREE TEXT', fill='white')
image.save(folder / 'page.png')
zoom = [dict(id=f'0-zoom-{i}', rect=dict(zip(['x', 'y', 'width', 'height'], r)), confidence=.95) for i, r in enumerate(rects)]
full = dict(x=0, y=0, width=1, height=1)
page = dict(id=0, filename='page.png', width=800, height=1200, processed=True, fallback=False, milliseconds=1, panels=[dict(id='0-0', rect=full, confidence=.9)], zoomPanels=zoom, textRegions=[dict(id='0-text-bubble', rect=dict(x=.65, y=65/1200, width=170/800, height=185/1200), kind='bubble', confidence=.95), dict(id='0-text-free', rect=dict(x=.05, y=.57, width=.3, height=.07), kind='freeText', confidence=.95)])
page2 = dict(page, id=1, panels=[dict(id='1-0', rect=full, confidence=.9)], zoomPanels=[], textRegions=[])
source = Path(__file__).resolve().parent.parent / 'MangaFlow/Core/Document.swift'
engine = re.search(r'static let engine = "([^"]+)"', source.read_text())[1]
doc = dict(id=chapter_id, title='Panel Zoom QA', schema=1, created=time.time() - 978307200 + 100, engineVersion=engine, rightToLeft=True, pages=[page, page2], manualGroupKey='panel-zoom-qa', manualSeriesTitle='Panel Zoom QA')
(folder / 'manifest.json').write_text(json.dumps(doc))
marker.write_text(json.dumps(dict(id=chapter_id, folder=str(folder))))
print('Prepared inline zoom UI fixture:', chapter_id)
