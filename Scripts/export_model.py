"""Run with the pinned environment in requirements-model.txt; never needs manga files."""
from pathlib import Path
import hashlib
import shutil
from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]
weights = Path('/tmp/manga_panel_detector_fp32.pt')
print('Weights SHA256:', hashlib.sha256(weights.read_bytes()).hexdigest())
model = YOLO(str(weights))
output = model.export(format='coreml', imgsz=640, quantize=32, nms=False, batch=1, device='cpu')
destination = ROOT / 'MangaFlow/Models/PanelDetector.mlpackage'
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(output, destination)
print(destination)
