"""Create an opt-in, metadata-only simulator library for chapter-list UI tests.
Usage: python Scripts/prepare_chapter_filter_fixture.py SIMULATOR_UUID
No manga images or website requests are needed. Marker lists only created document folders.
"""
from pathlib import Path
import json
import re
import subprocess
import sys
import time
import uuid

sim = sys.argv[1]
subprocess.run(['xcrun', 'simctl', 'terminate', sim, 'fr.yannick.mangaflow'], capture_output=True)
root = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', sim, 'fr.yannick.mangaflow', 'data'], text=True).strip()) / 'Library/Application Support/MangaFlow'
marker = Path('/tmp/mangaflow-chapter-filter-review.json')
if marker.exists():
    import shutil
    for item in json.loads(marker.read_text()):
        # Only clean up a previous run in this simulator's app container.
        folder = root / str(uuid.UUID(item['id'])).upper()
        shutil.rmtree(folder, ignore_errors=True)
engine = re.search(r'static let engine = "([^"]+)"', (Path(__file__).resolve().parents[1] / 'MangaFlow/Core/Document.swift').read_text())[1]
created = []
for number in [312, 320.5, 321, 322]:
    identifier = str(uuid.uuid4()).upper()
    folder = root / identifier; folder.mkdir(parents=True)
    doc = dict(id=identifier, title=f'Chapter {number}', schema=1, created=time.time() - 978307200 + 100,
               engineVersion=engine, rightToLeft=True, pages=[], manualGroupKey='chapter-filter-qa',
               manualSeriesTitle='Chapter Filters QA', chapterOrder=number, readComplete=number == 321)
    (folder / 'manifest.json').write_text(json.dumps(doc))
    created.append(dict(id=identifier, folder=str(folder)))
marker.write_text(json.dumps(created))
print('Prepared four chapter-filter documents')
