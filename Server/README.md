# MangaFlow Mac server

The Mac runs **HakuNeko**, not Haruneko. iOS only uses our API and imports the resulting CBZ through the existing local reader. The Mac and iPhone/iPad must be on the same local network; **Tailscale is not required**.

## Start

Requires macOS with a logged-in graphical user session, Node.js 24+ and npm. Electron is a separate hidden process; this is not a headless Linux daemon.

```bash
cd Server
npm ci
# Needed if npm install scripts are disabled on this machine:
node node_modules/electron/install.js
npm start
```

The first start downloads the complete official signed HakuNeko web package, verifies its RSA-SHA256 signature with the upstream public key, checks compatibility, then activates it. It needs Internet. Subsequent starts can use the installed version offline.

In another terminal:

```bash
cd Server
npm run pair
```

Scan the terminal QR in **MangaFlow → Sources → Scanner le QR code**. It contains the Mac’s `.local` hostname and port 9120, a server UUID, a one-use random secret and a five-minute expiry. No address entry is needed. You can also import `.state/pairing.json` or paste its contents; the QR image is `.state/pairing.png`. These files contain a temporary secret: keep them local. Generate another QR if expired or consumed.

On iOS, allow **Local Network** and **Camera** access when asked. If the camera is refused or unavailable, use pairing file import/paste. If the Mac’s firewall asks about Electron/Node, allow connections from your local network. Guest Wi-Fi/client isolation can prevent devices from reaching each other.

The API binds to `0.0.0.0:9120` on the Mac. No router port forwarding, public tunnel, cloud pairing service or automatic Internet port opening is configured. The default transport is HTTP on the trusted local network, not TLS; device tokens authenticate requests but do not encrypt them. An existing HTTPS reverse proxy can be used with `MANGAFLOW_SERVER_URL=https://your-host:port`. `MANGAFLOW_BIND` and `MANGAFLOW_PORT` can change the listener. If mDNS is unavailable, set `MANGAFLOW_SERVER_URL=http://192.168.x.y:9120` on the Mac before startup; the phone still only scans the QR.

## Use

1. Open a source and synchronize its **local catalog**.
2. Search within that catalog, open a manga, and fetch its chapters.
3. Download a chapter. The Mac job continues if the mobile app closes.
4. Return to Sources and choose **Importer et lire** when complete.
5. The phone validates file size and SHA-256, imports and converts the CBZ locally, then opens the existing reader. Imported documents remain readable without the Mac.

Only a small source selection is exposed. LELScan and MangaDex have passed real catalog → chapters → images → CBZ runs. KadoComi is not yet verified against the live site. WEBTOON FR explicitly has no complete catalog and is displayed with that limitation; URL discovery is outside this MVP. A connector being loadable does not guarantee the site still works. See [validation](../Docs/ONLINE_SOURCES.md).

## Administration

Commands use a local Unix socket inside `.state` (directory 0700, socket 0600), not an unauthenticated network admin endpoint.

```bash
node src/cli.mjs status
node src/cli.mjs devices
node src/cli.mjs revoke DEVICE_ID
npm run update
node src/cli.mjs rollback
```

`status` shows the active upstream version, last update result and job states without credentials. `revoke` invalidates the selected device immediately. A phone can also revoke itself. Ctrl-C stops the foreground service; `npm start` restarts it using the same state. To keep it awake during a reading session, macOS offers `caffeinate -i npm start`. A sleeping Mac cannot serve the phone.

For logs:

```bash
npm start >> "$HOME/Library/Logs/MangaFlow-server.log" 2>&1
```

Do not redirect the `pair` command to a shared log: its intentional output is the one-use QR. The service never logs pairing secrets, device tokens or raw connector objects. Detailed internal website errors are intentionally reduced to stable error codes. The downloaded pages and CBZs are private local data, not published to Git.

## Persistence and limits

- `.state/state.json`: server identity, hashed credentials, source catalogs, timestamps/errors and durable jobs.
- `.state/artifacts`: completed CBZs, retained for seven days. Expired files are removed hourly while idle and on startup. Temporary `.partial` archives are removed on failure/startup.
- `.runtime/versions`: coherent upstream packages, including engine, connectors, templates and support files. `active.json` and `previous.json` keep a working fallback.
- `.runtime/profile`: website cookies and Electron session. Keep this private too.
- Global concurrency is **one job**, so source concurrency is also one. Chapters use upstream order; no manual reordering is inserted.
- Jobs: `queued`, `running`, `completed`, `failed`, `cancelled`. In-progress jobs are requeued after restart, up to three attempts. Retry starts the task again, not at the last image. Source/network transient failures have bounded retries; user cancellations are terminal.
- Fifteen-minute total job deadline, bounded engine calls, three attempts per transient image fetch. Chapter limit: 2,000 images / 1 GB; individual image limit: 50 MB. JPEG, PNG and WebP are preserved. Other formats fail explicitly, without publishing a partial CBZ.
- Download requests are deduplicated per device/target while queued, running or completed with a retained artifact; explicit idempotency keys are also supported.
- The JSON store is intended for a personal MVP, not a high-concurrency service. Large catalogs can make persistence more expensive. No image-level restart/resume or HTTP byte-range resume is provided.

## Upstream updates

A check runs at startup and every six hours; `npm run update` starts a manual check. Official channel:
`https://manga-download.github.io/hakuneko/master/latest`.

The archive is downloaded to memory, its official RSA signature is checked, then its complete contents are staged in a separate version directory with CRC and path checks. The adapter loads required connectors in a separate Electron process before activation. New jobs are paused only during final idle activation; running jobs retain their engine. A failed signature/probe keeps the last working version and records an error. A failed active release at startup falls back to `previous.json`; `rollback` also allows explicit rollback while idle. The loader probe is not a guarantee of live website compatibility: upstream API changes may require an adapter change.

The public verification key is copied verbatim from HakuNeko `src/app/Configuration.js`; provenance and audited commit are in [ONLINE_SOURCES.md](../Docs/ONLINE_SOURCES.md). No upstream files are edited. Our compatibility shim, API and queue live separately under `src`.

## Tests

```bash
npm test
npm run engine:proof -- lelscan 'one piece'
npm run engine:proof -- mangadex yotsuba
```

Normal tests use local fixtures. The proof commands explicitly access the live websites and download one complete chapter into `.runtime/proof`; they are not routine unit tests. They do not publish any manga files.

For the live iOS test, start the server, then:

```bash
cd Server
node scripts/prepare-live-test.mjs
cd ..
xcodebuild -project MangaFlow.xcodeproj -scheme MangaFlow \
  -destination 'platform=iOS Simulator,name=MangaFlow-Test' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=YES \
  -only-testing:MangaFlowUITests/OnlineWorkflowTests test
rm -f /private/tmp/mangaflow-online-pairing.json
```

Simulator builds need ad-hoc code signing and their provided simulator entitlements for Keychain access. An unsigned build can read offline CBZs but cannot exercise credential storage. The live pairing is consumed once; prepare a new one for every run. `--loopback` is a fallback for local simulator tests only; the normal test uses the same `.local` URL as the phone. Hardware camera scanning and the Mac firewall prompt require an actual iPhone/iPad check.

A launchd daemon is deliberately not installed: Electron requires a graphical login session. Manual startup is the supported MVP path.
