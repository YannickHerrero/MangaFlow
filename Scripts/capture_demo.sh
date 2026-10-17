#!/bin/bash
# Convert the public demonstration page in iOS and render its full vertical strip.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${MANGAFLOW_SIMULATOR:-D8D98A16-82FA-4B77-BD30-F8D9B1B6E180}"
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
with ZipFile('/private/tmp/mangaflow-public-demo.cbz', 'w', ZIP_DEFLATED) as archive:
    archive.write(Path('Docs/demo/source-page.png'), '001.png')
PY
trap 'rm -f /private/tmp/mangaflow-public-demo.cbz' EXIT
result="Artifacts/DemoCapture-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow -configuration Debug \
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO -only-testing:MangaFlowUITests/DemoScreenshotTests \
  -resultBundlePath "$result" test
attachments="${result%.xcresult}-attachments"
xcrun xcresulttool export attachments --path "$result" --output-path "$attachments"
python3 - "$device" <<'PY'
import json
from pathlib import Path
import subprocess
import sys
container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container',
    sys.argv[1], 'fr.yannick.mangaflow', 'data'], text=True).strip())
document = json.loads((container / 'Documents/last-conversion.json').read_text())
assert document['title'] == 'mangaflow-public-demo' and len(document['pages']) == 1
page = document['pages'][0]
assert page['processed']
manifest = {'engineVersion': document['engineVersion'],
            'page': {key: page[key] for key in ('width', 'height', 'panels')}}
Path('Docs/demo/conversion.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
PY
"${MANGAFLOW_PYTHON:-python3}" Scripts/render_demo.py
