"""Reproduce the bundled balloon detector using requirements-model.txt.
Downloads the pinned upstream checkpoint, verifies SHA256, exports FP16 Core ML.
Usage: python Scripts/export_text_model.py
"""
from pathlib import Path
import hashlib
import shutil
import urllib.request
from ultralytics import YOLO

REVISION = '21d5af0a9c69bb522b9968d6cc915f898d71a264'
SHA256 = '10bc9f702698148e079fb4462a6b910fcd69753e04838b54087ef91d5633097b'
url = f'https://huggingface.co/ogkalu/comic-speech-bubble-detector-yolov8m/resolve/{REVISION}/comic-speech-bubble-detector.pt'
weights = Path('/tmp/comic-speech-bubble-detector.pt')
if not weights.exists():
    temporary = weights.with_suffix('.download')
    urllib.request.urlretrieve(url, temporary)
    if hashlib.sha256(temporary.read_bytes()).hexdigest() != SHA256:
        temporary.unlink()
        raise RuntimeError('Unexpected upstream checkpoint SHA256')
    temporary.replace(weights)
if hashlib.sha256(weights.read_bytes()).hexdigest() != SHA256:
    raise RuntimeError('Unexpected local checkpoint SHA256')
model = YOLO(str(weights))
assert model.names == {0: 'text_bubble', 1: 'text_free'}
exported = model.export(format='coreml', imgsz=1024, quantize=16, nms=False, batch=1, device='cpu')
destination = Path(__file__).resolve().parents[1] / 'MangaFlow/Models/TextDetector.mlpackage'
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(exported, destination)
print(destination)
