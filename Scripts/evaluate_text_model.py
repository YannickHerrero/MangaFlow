"""Private offline diagnostic. Usage: python Scripts/evaluate_text_model.py CHAPTER.cbz OUTPUT_DIR
Requires requirements-model.txt. Does not upload images or include them in Git.
Compares source weights and exported Core ML model; emits overlays and JSON.
"""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
from PIL import Image, ImageDraw
from ultralytics import YOLO
import json
import sys
import time

root = Path(__file__).resolve().parents[1]
source = YOLO('/tmp/comic-speech-bubble-detector.pt')
converted = YOLO(str(root / 'MangaFlow/Models/TextDetector.mlpackage'), task='detect')
output = Path(sys.argv[2]); output.mkdir(parents=True, exist_ok=True)
report = []

def iou(a, b):
    inter = max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))
    return inter / max(1e-9, (a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - inter)

with ZipFile(sys.argv[1]) as archive:
    names = sorted(n for n in archive.namelist() if n.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')))
    for index, name in enumerate(names):
        image = Image.open(BytesIO(archive.read(name))).convert('RGB')
        a = source.predict(image, imgsz=1024, rect=False, conf=.3, iou=.45, device='cpu', verbose=False)[0]
        start = time.perf_counter()
        b = converted.predict(image, imgsz=1024, rect=False, conf=.3, iou=.45, device='cpu', verbose=False)[0]
        elapsed = time.perf_counter() - start
        boxes = [dict(rect=x.xyxy[0].tolist(), kind=int(x.cls[0]), confidence=float(x.conf[0])) for x in b.boxes if float(x.conf[0]) >= (.4 if int(x.cls[0]) == 0 else .3)]
        parity = min((max((iou(x.xyxy[0].tolist(), y['rect']) for y in boxes if y['kind'] == int(x.cls[0])), default=0) for x in a.boxes if float(x.conf[0]) >= (.4 if int(x.cls[0]) == 0 else .3)), default=1)
        row = dict(page=index+1, filename=name, width=image.width, height=image.height, seconds=elapsed, min_matching_iou=parity, regions=boxes)
        report.append(row)
        draw = ImageDraw.Draw(image)
        for box in boxes:
            color = '#0099ff' if box['kind'] == 0 else '#ff0066'
            draw.rectangle(box['rect'], outline=color, width=4)
        image.thumbnail((1000,1500)); image.save(output / f'{index+1:02}.jpg')
        print(f'Page {index+1}: {len(boxes)} targets, IoU {parity:.3f}, {elapsed:.2f}s', flush=True)
(output / 'report.json').write_text(json.dumps(report, indent=2))
