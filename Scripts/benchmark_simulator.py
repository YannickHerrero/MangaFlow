"""Stress the local pipeline with repeated private pages; stores only numeric metrics in Artifacts."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
from zipfile import ZipFile, ZIP_STORED

device, source = sys.argv[1:3]
def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()
container = Path(sim('get_app_container', device, 'fr.yannick.mangaflow', 'data'))
archive_path = container / 'Documents' / 'Stress 200 pages.cbz'
with ZipFile(source) as original, ZipFile(archive_path, 'w', ZIP_STORED) as output:
    pages = sorted(n for n in original.namelist() if n.lower().endswith(('.webp', '.png', '.jpg', '.jpeg')))
    for index in range(200):
        name = pages[index % len(pages)]
        output.writestr(f'{index:04}{Path(name).suffix}', original.read(name))
report = container / 'Documents' / 'last-conversion.json'
if report.exists():
    report.unlink()
started = time.monotonic()
pid = int(sim('launch', '--terminate-running-process', device, 'fr.yannick.mangaflow', '-import', str(archive_path)).split(':')[-1])
max_rss = 0
while time.monotonic() - started < 55:
    try:
        rss = int(subprocess.check_output(['ps', '-o', 'rss=', '-p', str(pid)], text=True).strip())
        max_rss = max(max_rss, rss)
    except (ValueError, subprocess.CalledProcessError):
        raise RuntimeError('App stopped during conversion')
    if report.exists():
        doc = json.loads(report.read_text())
        if len(doc['pages']) == 200 and all(p['processed'] for p in doc['pages']):
            break
    time.sleep(0.25)
else:
    raise RuntimeError('Conversion did not finish within 55 seconds')
metrics = dict(pages=200, regions=sum(len(p['panels']) for p in doc['pages']),
               wall_seconds=round(time.monotonic()-started, 3),
               page_processing_seconds=round(sum(p['milliseconds'] for p in doc['pages'])/1000, 3),
               sampled_max_rss_mib=round(max_rss/1024, 1),
               environment='iOS 27 simulator, Debug, CPU only; not a physical iPhone measurement')
Path('Artifacts/stress-metrics.json').write_text(json.dumps(metrics, indent=2))
print(json.dumps(metrics, indent=2), flush=True)
# Remove only this generated test document and archive; keep the user's original chapter untouched.
sim('terminate', device, 'fr.yannick.mangaflow')
shutil.rmtree(container / 'Library/Application Support/MangaFlow' / doc['id'])
archive_path.unlink()
