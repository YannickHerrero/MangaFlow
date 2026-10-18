# Themes and series library

The three native SwiftUI themes reproduce the supplied HTML mockup's distinct compositions, fonts, palettes and custom tab bars. They share behavior, not a UIKit tab bar. The app supports system, light and dark appearances, persists both preferences, and adapts the phone layouts to iPad widths. The reader keeps its immersive zero-spacing flow.

Reference: user-owned `Manga → Webtoon — thèmes.html`, 19 boards (six library, six explorer, six activity and settings), SHA-256 `2ba3031aade07efb9312d0d3422228a933485eae9a4388948ebfb58b5f91de4f`. The original mockup and its illustrative manga assets are not bundled or published. Real app states replace example names and counters. Screens not specified by the mockup use the same theme primitives.

## Series and migration

Remote chapters retain `ChapterOrigin`: server UUID, source ID/name, opaque manga ID/title, opaque chapter ID/title, order and language. Length-prefixed identity components prevent ambiguous concatenations. Different sources and servers remain separate, even with identical manga titles or AniList IDs. Subsequent imports of the same chapter reuse the local document, including when the server generates another artifact.

Old manifests decode without the new optional fields. When server jobs can still identify an old artifact, reconciliation attaches its provenance without touching pages or saved position. Imports whose provenance cannot be recovered remain independent; the app never guesses a series from a filename. In a chapter's classification editor, manual imports can be attached to an existing series or detached. Explicit chapter titles/order can be edited. Natural numeric title order is used where source titles provide chapter numbers; a consistent source-order fallback handles nonnumeric titles.

Library counters describe imported chapters, not the entire website catalog. Reading state, last-read timestamp and panel position remain local. Completion is recorded on reaching the end of the reader rather than merely revealing the first pixels of its last panel. The library offers all/unread, search, title/addition/last-reading sort, explicit read/unread actions and resume. The next-chapter action opens the next locally imported chapter.

## AniList

`AniListClient` queries public manga metadata at `https://graphql.anilist.co`; it never sends the Mac's bearer token or CBZ contents. Automatic matching requires a unique exact normalized title/synonym match. Ambiguous results retain a page preview until a user picks a result in the cover picker. A user can also select the first CBZ page instead. Explicit choices are preserved.

Only series in use are queried. The client spaces requests, handles HTTP 429/Retry-After and GraphQL errors, and caches associations and cover files under Application Support/MangaFlowMetadata. Automatic results are eligible for refresh after 30 days. Failures keep previous metadata. Clearing image cache retains associations and imported pages. AniList is an optional enrichment service: pairing, downloads and offline reading do not depend on it.

API and terms: https://docs.anilist.co/guide/introduction ; https://docs.anilist.co/guide/terms-of-use . No AniList account synchronization or public catalog mirroring is implemented.

## Activity

The Mac remains authoritative for remote jobs. The authenticated job list supplies a global queue position while exposing only the current device's jobs. Phone transfers use URLSession download delegate progress; final size and SHA-256 are checked before the existing CBZ import pipeline is invoked. Transferring, local conversion and ready-to-read are separate states.

A cached per-server snapshot displays the last known remote state offline; it is never presented as a fresh live result. Local transfer failures and a transfer-interruption marker persist across relaunches. An interrupted transfer can restart from the server artifact; a paused local conversion resumes its page checkpoints. A foreground phone transfer is not promised to continue after iOS terminates the app. Mac jobs continue independently. Time estimates appear only after measured progress; they are approximate. Finished-history clearing hides entries locally and does not delete books or server files. Expired server artifacts can be downloaded again.

## Components and verification

- `Core/Series.swift`, `Document.swift`: identity, grouping, optional persisted fields.
- `Metadata/MetadataStore.swift`: AniList client, association/image cache, cover picker.
- `Design/`: palettes, fonts, themed surfaces, headers, custom tabs, settings and app shell.
- `UI/SeriesLibraryView.swift`: library, chapter details, manual classification.
- `Remote/ExplorerView.swift`, `ActivityView.swift`, `TransferSession.swift`: discovery, favorites and transfer UI.
- `Server/src/http.mjs`, `service.mjs`: queue position and catalog count additions; older app clients can ignore these fields.

Automated fixtures cover identity isolation, legacy manifest decoding, natural order, migration with reading-position preservation, read progress, metadata matching/persistence, GraphQL failures and rate limiting. `ThemeWorkflowTests` captures all theme/appearance combinations and tests UI selection persistence, including the absence of system tab bars. `ReaderWorkflowTests` imports the private real CBZ. Live source tests remain explicit and require a fresh one-use pairing file, as described in ONLINE_SOURCES.md.

Example commands (replace simulator ID if needed):

```sh
xcodegen generate
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow -destination 'platform=iOS Simulator,id=D8D98A16-82FA-4B77-BD30-F8D9B1B6E180' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=YES -only-testing:MangaFlowTests test
npm --prefix Server test
```

Server launch/pairing remains unchanged; see ../Server/README.md. Existing pairing credentials remain in Keychain.

Validated on 18 October 2026: live AniList Naruto lookup returned media 36444 and a cover URL; live LELScan Blue Lock 364.1 download/import completed with nine images; favorite persisted across relaunch; the existing private chapter 1196 reader workflow passed. Screenshot attachments stay in ignored Artifacts/ThemeUI rather than publishing private library content.

Final validation: 40 Swift fixture/unit tests and nine server fixture tests pass. iPhone UI checks cover the real private chapter, all six theme/appearance combinations, theme selection persistence, and a live favorite/download/import flow. LELScan Blue Lock chapters 364.1 (nine pages) and 363 (20 pages) were downloaded and imported, and the saved manifests contain exactly one source-series identity for both. Offline reading passed with the server actually stopped, then the service was restarted. All theme/appearance screens and preference persistence also passed on an iPad Pro 13-inch simulator. The tablet check caught a plain-button hit-area issue; the tab labels now explicitly expose the whole segment as a rectangular touch target.

The release archive was checked with `codesign --verify --deep --strict` and exported for internal TestFlight. Apple processing/distribution state is recorded separately in Deployment/README.md only after confirmation.

## One-action downloads (build 8)

A chapter's Download action now means download on Mac **and** import into this device's library. Durable intent is recorded before the server request and reconciled with the returned/recovered job. Completed artifacts are transferred and converted automatically while the app is active; a busy library defers the next import. Only one phone import runs at a time. Relaunch recovers the pending intent and local conversion checkpoints. Auto-import does not open the reader or change tabs. The row becomes Read when the local chapter is ready. A failed import shows a retry action rather than retrying indefinitely; explicit cancellation removes the automatic intent. Existing manual CBZ imports still open the reader on completion.

The single-tap live flow was verified with LELScan Blue Lock 362: Download, automatic transfer/conversion, Read without a second import action, no unsolicited reader presentation, and reading after relaunch.

## Reader modes and chapter transitions

The reader header includes a persistent Original pages toggle. It uses the same image loader and continuous zero-spacing scroll as panel mode, with full-page rectangles and no contour masks. Switching mode maps the current position to the first panel of the same page; stored progress uses canonical panel IDs. Tapping either representation opens the existing zoomable original view.

Opening a chapter normally resumes its saved position. The next-chapter action explicitly clears the target chapter’s saved position and completed flag before opening it; reader state is keyed by document identity so the previous scroll position cannot carry over. The reset is checkpointed before either opening or reconverting an older document.
