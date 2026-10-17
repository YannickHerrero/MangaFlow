"""Local diagnostic overlays and PyTorch/Core ML parity on a private CBZ (never uploaded)."""
from pathlib import Path
from zipfile import ZipFile
from PIL import Image, ImageDraw
from io import BytesIO
from ultralytics import YOLO
import json
import sys

root = Path(__file__).resolve().parents[1]
archive = ZipFile(sys.argv[1])
output = root / 'Artifacts' / 'detections'
output.mkdir(parents=True, exist_ok=True)
pt = YOLO('/tmp/manga_panel_detector_fp32.pt')
ml = YOLO(str(root / 'MangaFlow/Models/PanelDetector.mlpackage'), task='detect')
report = []
for name in sorted(archive.namelist()):
    if not name.endswith(('.webp', '.jpg', '.png')):
        continue
    image = Image.open(BytesIO(archive.read(name))).convert('RGB')
    result = pt.predict(image, imgsz=640, rect=False, conf=0.3, device='cpu', verbose=False)[0]
    converted = ml.predict(image, imgsz=640, rect=False, conf=0.3, device='cpu', verbose=False)[0]
    panels = [b.xyxy[0].tolist() for b in result.boxes if int(b.cls[0]) == 0]
    core_panels = [b.xyxy[0].tolist() for b in converted.boxes if int(b.cls[0]) == 0]
    def iou(a, b):
        inter = max(0, min(a[2], b[2])-max(a[0], b[0])) * max(0, min(a[3], b[3])-max(a[1], b[1]))
        union = (a[2]-a[0])*(a[3]-a[1]) + (b[2]-b[0])*(b[3]-b[1]) - inter
        return inter / max(union, 1e-9)
    parity = min((max((iou(a,b) for b in core_panels), default=0) for a in panels), default=1)
    info = dict(page=name, pytorch_panels=len(panels), coreml_panels=len(core_panels), min_matching_iou=parity)
    print(info, flush=True)
    report.append(info)
    draw = ImageDraw.Draw(image)
    for i, box in enumerate(core_panels):
        draw.rectangle(box, outline='#f00045', width=5)
        draw.text((box[0]+5, box[1]+5), str(i), fill='#f00045', stroke_width=2)
    image.thumbnail((1000, 1400))
    image.save(output / (Path(name).stem + '.jpg'))
(output / 'parity.json').write_text(json.dumps(report, indent=2))
