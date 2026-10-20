# MangaFlow

[Français](README.fr.md)

Turn CBZ manga into a vertical, webtoon-style reading experience on iPhone and iPad. Panel detection runs entirely on-device with Core ML. Local CBZ reading needs no server or account.

## Before & after

<table>
  <tr><th>Original page</th><th>Vertical reading</th></tr>
  <tr>
    <td width="50%" valign="top"><a href="Docs/demo/source-page.png"><img src="Docs/demo/source-page.png" alt="Original manga page from ONE PIECE by Eiichiro Oda" width="420"></a></td>
    <td width="50%" valign="top"><a href="Docs/demo/vertical-page.png"><img src="Docs/demo/vertical-page.png" alt="All seven panels assembled vertically in reading order" height="600"></a></td>
  </tr>
</table>

One page, seven automatically extracted panels. Click either image to view it full size. Artwork: **ONE PIECE — Eiichiro Oda / Shueisha**. [Demo details and credits](Docs/demo/README.md).

## Features

- Import CBZ files containing JPEG, PNG or WebP images from Files or iCloud Drive.
- Read panels in a continuous vertical scroll, with support for angled borders.
- Hide the controls for immersive reading; tap with two fingers to bring them back.
- Tap a panel to open and zoom into the original page.
- In original-page mode, tap dialogue for a moderate inline zoom, then use the bottom arrow to move through text in reading order. The control stays fixed at the bottom of the screen; each new page starts in overview. Reader settings adjust dialogue size and maximum zoom. Ordering is geometric and may be imperfect on unusual layouts.
- Resume conversions and pick up where you left off reading.
- Save manga favorites with their original source and track chapter downloads in place.

Manga reading order is right-to-left by default, with a left-to-right option.

One light/dark interface, a series library with optional AniList covers, and wide Liquid Glass Library / Explore navigation. Reading history survives local chapter removal. [Details](Docs/REDESIGN.md).

## Online sources

Optionally browse HakuNeko sources through a Mac on the same local network. Pair by QR code, download chapters on the Mac, then import and read them offline on iPhone or iPad. [Mac server setup](Server/README.md).

## Try it

Requires **iOS 27+** and **Xcode 27+**.

1. Open `MangaFlow.xcodeproj` in Xcode.
2. Select the **MangaFlow** target, choose your signing team and set a unique bundle identifier.
3. Run on your iPhone or an iOS simulator, then import a `.cbz` file.

The model is bundled with the app. Internet is needed for the initial Xcode dependency setup; reading and conversion work offline. Keep the app in the foreground while converting. The app interface is currently in French.

This is a prototype: panel detection and reading order can be imperfect. [Development guide](Docs/DEVELOPMENT.md) · [Validation and limitations](Docs/VALIDATION.md) · [Third-party notices](THIRD_PARTY_NOTICES.md).

## License

[AGPL-3.0](LICENSE). The manga artwork shown in the demo belongs to its respective rights holders and is excluded from this license.
