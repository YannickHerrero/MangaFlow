# Online sources MVP — audit and validation

## Existing app audit

Before this change the app had one `LibraryView` inside a `NavigationStack`, no tabs and no remote API client. `LibraryModel` owns local documents and conversion work. `DocumentStore.importArchive` validates/extracts CBZs into Application Support; `ConversionEngine` persists progress after every page. `ReaderView` persists the current panel through `LibraryModel.remember`. Local tests cover archives, panel layout, contours, cancellation and reader restoration.

The integration adds a two-tab root (Library / Sources). The same `LibraryModel`, CBZ validation, conversion engine and reader are used. Reader presentation moved to the shared root so a remote import can open it from either tab. An optional `remoteArtifactID` on local documents prevents a repeated artifact import; old manifests still decode. No online server is required to open an imported document.

## HakuNeko audit

Repository inspected: **manga-download/hakuneko**, master commit `128f3c771c7d50bf4eec19638d480f133469eca8` (17 October 2026). This is HakuNeko, not Haruneko.

Inspected engine `Connectors.mjs`, `Connector.mjs`, `Manga.mjs`, `Chapter.mjs`, `Request.mjs`, connectors/templates, plus `Updater.js`, `UpdatePackageInfo.js` and `CacheDirectoryManager.js`. Findings:

- Connectors are ES modules with DOM globals, engine globals and shared templates. A plain Node import is insufficient.
- Modern `_getMangas` / `_getChapters` / `_getPages` are reached through the base callback wrappers; legacy connectors override those wrappers. The adapter uses those wrappers for both styles.
- Images can be `connector://` references. They must be resolved by `handleConnectorURI`, not downloaded as literal HTTP URLs.
- Upstream `Request.mjs` depends on Electron’s removed `remote` API and transforms `x-referer`, cookies and other headers.
- Official updates are complete ZIP packages signed with RSA-SHA256. The upstream updater deletes its active cache; our updater stages separately and preserves a fallback instead.

Our runtime uses the official signed web package **MMYN4DBD**. Upstream files are unmodified. Our explicit adaptation supplies `@electron/remote`, a hidden renderer with DOM/Canvas/CryptoJS and selected Engine globals, and the upstream request/header handlers. Website windows execute website scripts with Node disabled by default; the trusted local engine renderer has Node access, as required by HakuNeko. This is a compatibility environment for a verified subset, not a universal headless HakuNeko replacement.

## Architecture

```text
SwiftUI Sources + Keychain credentials
  → local-network API v1 on the Mac
    → durable JSON catalogs / single-worker queue / CBZ artifacts
      → child Electron process + adapter
        → unmodified signed HakuNeko modules
          → manga sites
```

The Node service owns persistence and private administration over a Unix socket. Electron can restart without losing queued work. Global concurrency is one, including per source. Interrupted running jobs restart from the beginning up to three attempts. App polling is limited to foreground activity. File transfer verifies length and SHA-256 before invoking the existing import pipeline.

After the user’s clarification, no Tailscale dependency remains. Pairing uses the Mac’s mDNS `.local` name and port 9120, or an explicitly configured LAN URL. Default LAN HTTP is not encrypted; an existing HTTPS endpoint is supported. No Internet port forwarding is configured.

## Real source results

Tests performed against live websites on 17 October 2026; results can change when sites change. Chapters remain in ignored local runtime storage.

| Source | Catalog | Chapter | Image resolution | Result |
|---|---|---|---|---|
| LELScan | Successfully fetched; legacy callback connector | One Piece, chapter 1196 | 17 images via `connector://` page-resolution handlers | Valid CBZ, 31,266,316 bytes; transferred, imported and read in the iPhone simulator |
| MangaDex | 115,196 catalog entries | Yotsuba to!, Vol. 1 Ch. 4 | 26 images via the connector’s network resolver | Valid CBZ, 155,651,433 bytes |
| KadoComi / ComicWalker | Module loads | Not live-tested | Not live-tested | Exposed as unverified |
| WEBTOON FR | No complete catalog in this upstream connector | Outside this MVP | Not live-tested | Catalog capability disabled with explanation |

The LELScan live UI workflow paired with a one-use QR payload over the Mac’s `.local` address on port 9120, synchronized the catalog, searched One Piece, loaded chapters, started chapter 1196, terminated and relaunched the app, recovered the server job, transferred and imported the CBZ, and opened the existing reader. The first successful end-to-end run completed in approximately 51 seconds on this Mac/simulator. This is not a physical iPhone performance measurement.

## Automated checks

- Eight server fixture tests: credential expiry/one-use/hash storage/revocation after reload; both connector interfaces and opaque IDs; ordered CBZ publication and rejection of invalid images; catalog preservation, duplicate requests, cancellation and restart recovery; signature tampering, candidate failure and rollback; HTTP authentication including private artifact routes.
- Swift unit tests: original 16 pipeline/contour tests plus pairing URL validation, opaque job IDs and backward-compatible local manifests.
- Existing private-chapter UI regression: import, immersive controls, original page, saved reading position and reopening.
- Explicit live online workflow: real LAN pairing, real connector, server download while the app is closed, transfer/import/reader.
- Explicit offline workflow: stop the Mac service, relaunch the paired app, confirm the Mac is unavailable, then read an already imported online chapter.
- Update compatibility probes load selected connectors and exercise modern/legacy invocation, DOM parsing and `connector://` payload round-tripping against the candidate package. They do not contact every website.

## Limits and manual checks

- Hardware QR camera scanning, local-network permission/firewall prompts and actual iPhone/iPad connectivity need a physical device check. Simulator paste/import and real LAN API access have been exercised.
- The Mac must be logged in, awake and running the service. Background downloads run on the Mac; mobile transfer/conversion is foreground work and can be restarted if interrupted.
- No login/captcha UI, arbitrary connector selection, global multi-source search, URL-only catalog discovery, per-image resume or manual page editor is provided.
- The first MVP uses a JSON store and keeps chapter buffers in memory while packaging. This is for one personal server with bounded jobs, not bulk downloading or many concurrent devices.
- Future HakuNeko changes may require adapter work. Official signature validation establishes package origin, not website compatibility. The last working release is retained on failed installation/probe.

Runbook: [Server/README.md](../Server/README.md). API contract: [Server/API.md](../Server/API.md).
