# Balloon and free-text zoom

Original-page mode prioritizes a detected balloon or text block at the tap location, then falls back to the individual panel. A subsequent tap restores the page. A simultaneous two-finger tap shows/hides controls in both reader modes. Single taps use a separate one-finger recognizer and no longer wait for a second tap. A nonblocking hint appears once for five seconds; the toolbar and VoiceOver actions remain available. The webtoon reader and its panel layout remain unchanged.

## Research and choice

- [ogkalu's YOLOv8m balloon detector](https://huggingface.co/ogkalu/comic-speech-bubble-detector-yolov8m) provides `text_bubble` (whole balloon bounds) and `text_free`. Its existing Ultralytics/Core ML export path fits our app. This is the bundled model.
- [ogkalu's RT-DETR-v2 model](https://huggingface.co/ogkalu/comic-text-and-bubble-detector) distinguishes balloon bounds, text inside balloons and free text. Promising alternative, but requires a separate export/runtime adaptation. Not bundled.
- [comic-text-detector](https://github.com/dmMaze/comic-text-detector) outputs text blocks, lines and text masks. Those masks are not whole-balloon masks, so using them alone would not solve the desired framing. Not bundled.
- [Manga-Segment](https://github.com/Ashu11-A/Manga-Segment) supports balloon/text segmentation. Pixel masks are useful for future refinement; not needed for a first bounding-box zoom. Not bundled.

## Implementation

`LocalTextDetector` runs the dedicated 1024 × 1024 FP16 Core ML model once per page during conversion, on device. It restores letterboxed coordinates, filters confidence (0.4 balloons / 0.3 free text) and suppresses duplicate boxes by class. `TextRegions` combines this output with high-confidence text blocks from the existing panel detector. A text block mostly inside a balloon never creates a second zoom target. A supplementary Apple Vision OCR pass finds remaining free-text lines, discards recognized strings, and groups nearby aligned lines into paragraphs. Only geometry is persisted. No translation, network or LLM is required.

`MangaPage.textRegions` persists normalized page coordinates, confidence and kind. It is optional for compatibility with older manifests. The conversion engine version changes to reprocess older chapters on their next open. Individual panel coordinates and reading layout grouping remain separate. Completed pages retain their checkpoint; cancellation resumes at the next unfinished page.

Hit testing uses the original detected rectangle; display framing adds a small page-relative margin, including context around the balloon. Text zoom caps at 6×; panel zoom retains its 4× cap. No visual mask is applied: this zoom displays the original image. Targets have explicit VoiceOver actions and reduced-motion support.

## Limits

These are model bounding boxes, not pixel-perfect balloon contours. A drawing inside a box corner may select the balloon. Open, connected or overlapping balloons may be grouped or missed. Stylized narration and sound effects can be missed or mistaken for art; fallback text detections help but do not guarantee recall. Confidence thresholds are conservative, and undetected regions still use panel zoom. A separate segmentation model would be needed to reliably hit-test arbitrary balloon outlines.

The extra model adds approximately 50 MiB and one inference per converted page. The supplementary Vision pass runs on CPU to avoid lengthy first-use ANE compilation observed during diagnostics. A failure preserves the primary regions and records a page warning. Simulator/Mac timing is not an iPhone performance measurement; verify processing time and thermal behavior on a device before claiming hardware latency.

## Reproduction and tests

```sh
python Scripts/export_text_model.py
xcodegen generate
Scripts/test.sh
```

Use the Python environment in `Scripts/requirements-model.txt`. Ordinary tests use synthetic geometry and the bundled models; no website is contacted. Optional private diagnostic:

```sh
python Scripts/evaluate_text_model.py /path/to/chapter.cbz Artifacts/BubbleReview/chapter
cp /path/to/chapter.cbz /private/tmp/mangaflow-bubble-review.cbz
# Run MangaFlowTests/TextRegionsTests/testPrivateChapterConversionWithBothBundledModels
# Native output: /private/tmp/mangaflow-bubble-native.json
# Remove the opt-in CBZ afterward.
```

Diagnostic pages/manifests stay ignored and local. Model parity checks compare source PyTorch and exported Core ML boxes; they do not establish detection accuracy against human annotations.

## Local validation

- Both bundled models plus the Vision supplement were run through the native conversion pipeline on all 19 pages of Blue Lock 309 and all 21 pages of Blue Lock 310, from the existing local CBZs. No supplementary-text warnings occurred.
- Chapter 309 produced 82 balloon targets and 62 free-text targets; chapter 310 produced 148 balloon targets and 36 free-text targets. These include incidental text such as credits/jersey lettering and are diagnostics, not human-annotated accuracy scores.
- Visual overlays were reviewed across both chapters, with larger checks on 309/18 and 310/16. All five main narration blocks on 309/18 are now covered; the six balloons on 310/16 remain separate.
- Source-weight versus Core ML diagnostics were run on chapter 309; native Swift overlays also confirm coordinate restoration. Filtering/merging differs deliberately from Ultralytics' reference NMS.
- Synthetic UI tests pass on iPhone and iPad: drawing tap, balloon tap, free-text tap, second-tap reset, two-finger controls, unchanged progress/layout, and preservation of the cropped reader's sheet behavior. Detection tests run actual bundled models separately from these deterministic UI fixtures.
- The iPhone test run contains 68 unit tests (2 unrelated opt-in tests skipped) and 1 UI test, with zero failures. The iPad UI test also passes.
- Private overlays and reports remain under ignored `Artifacts/BubbleReview/`. No manga pages are committed.

## Immediate taps and two-finger controls

`ReaderTapGesture` bridges native one-tap UIKit recognizers with distinct required touch counts. It introduces no double-tap recognizer or failure dependency, so a one-finger action runs on finger release. A simultaneous two-finger tap toggles controls in either mode. Movement still yields to the scroll view. Original-page hit testing uses SwiftUI's local coordinate converter; VoiceOver actions are unchanged.

A noninteractive five-second hint is persisted as seen in `readerTwoFingerHintSeen`. Menu and accessibility instructions now describe the two-finger gesture. No conversion/model or library migration changes are required.

Validation: two iPhone UI tests pass (both reader modes, two-finger toggling without a sheet/zoom side effect, bubble/free-text/panel zoom and reset, scroll movement, hint dismissal and persistence across relaunch). The reader gesture workflow also passes on iPad. XCTest multi-touch targets the image surface inside the semantic page element and a visible row below the toolbar, so both synthesized fingers land in the reader. These functional tests do not claim a hardware latency benchmark.
