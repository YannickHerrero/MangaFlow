#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 0 ]]; then
  cp "$1" /private/tmp/mangaflow-ui-fixture.cbz
fi
DEVICE="${MANGAFLOW_SIMULATOR:-D8D98A16-82FA-4B77-BD30-F8D9B1B6E180}"
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow \
  -configuration Debug -destination "platform=iOS Simulator,id=${DEVICE}" \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
