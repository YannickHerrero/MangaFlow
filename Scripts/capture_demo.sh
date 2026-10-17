#!/bin/bash
# Capture real simulator screenshots from the public demonstration page.
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
xcrun xcresulttool export attachments --path "$result" --output-path Artifacts/DemoCapture
python3 - <<'PY'
import json
from pathlib import Path
import shutil
entries = json.loads(Path('Artifacts/DemoCapture/manifest.json').read_text())
for entry in entries:
    for attachment in entry.get('attachments', []):
        name = attachment.get('suggestedHumanReadableName', '')
        for target in ('demo-reader-start', 'demo-reader-scroll'):
            if name.startswith(target):
                shutil.copyfile(Path('Artifacts/DemoCapture') / attachment['exportedFileName'],
                                Path('Docs/demo') / (target + '.png'))
for target in ('demo-reader-start', 'demo-reader-scroll'):
    if not (Path('Docs/demo') / (target + '.png')).exists():
        raise SystemExit('Screenshot not exported: ' + target)
PY
