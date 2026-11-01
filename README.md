<div align="center">

<img src="docs/assets/icon.png" width="128" height="128" alt="">

# CrateMate

**Apple Music playlists → Rekordbox, using the DJ files you already have.**

[![CI](https://github.com/bflip12/cratemate/actions/workflows/ci.yml/badge.svg)](https://github.com/bflip12/cratemate/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)

</div>

CrateMate is a small native Mac app for DJs who dig in Apple Music and play from Rekordbox. It reads your Apple Music playlists, finds each song in your local DJ folder, and writes an `.m3u8` playlist that Rekordbox imports directly. The imported tracks link to files that are already in your Rekordbox collection, so your cues, beatgrids and hot cues are kept.

## Why

Apple Music can export a playlist as M3U, but only for songs stored on your Mac. If your library lives in iCloud, the export comes out empty: an `#EXTM3U` header and nothing else. Even when the files are local, they're Apple Music's copies, not the ones you've prepared in Rekordbox.

CrateMate doesn't use file paths from Apple Music. It matches each song by **artist, title, version and length** against the files in your DJ folder, so it works for cloud-only libraries. It also picks the right cut when you own several versions of a track.

## Features

- **Reads Apple Music directly.** There's nothing to export first, and playlist folders and Smart Playlists are included.
- **Matches on metadata.** It handles accents and non-Latin scripts, `&` vs "and", "feat." in the title or the artist, typos, and untagged files named like `01 - Artist - Title.wav`.
- **Tells versions apart.** Track length separates an Extended Mix from an Original Mix or a Radio Edit with the same title.
- **Shows its work.** Every song is marked matched, worth a check, or not found. You can pick another candidate, search your DJ folder, or skip the song before exporting.
- **Flags duplicates.** If the same recording is in your DJ folder twice, CrateMate tells you, so you can make sure the playlist points at the copy Rekordbox knows.
- **Never touches your files.** Your DJ folder is only ever read. Nothing is moved, renamed or retagged, since Rekordbox tracks files by path.
- **Fast after the first scan.** Tags are cached, and only new or changed files are read again.

## Requirements

- macOS 14 Sonoma or later
- An Apple Music library (local or iCloud)
- A folder with your DJ files, the same files your Rekordbox collection uses
- To build: Swift 6 or later, from either the Xcode Command Line Tools (`xcode-select --install`) or Xcode

## Install

**[Download CrateMate for Mac](https://github.com/bflip12/cratemate/releases/latest/download/CrateMate.dmg)**: free, for Apple silicon and Intel, macOS 14 or later.

1. Open the DMG and drag **CrateMate** onto **Applications**.
2. Open CrateMate from Applications. CrateMate isn't notarized by Apple yet, so the first time, macOS says it can't verify the app. Click **Done**.
3. Open **System Settings › Privacy & Security**, scroll down to the message about CrateMate and click **Open Anyway**. Confirm, and CrateMate opens. You only need to do this once per version.
4. When CrateMate asks to access Apple Music, click **Allow**.

To update, download the new DMG and replace the app. macOS asks for Apple Music access again after each update.

### Build from source

Building takes about a minute and doesn't need Xcode or a paid developer account.

```bash
git clone https://github.com/bflip12/cratemate.git
cd cratemate
scripts/build-app.sh --install
```

This builds `build/CrateMate.app` and copies it to `/Applications`. The first time you open it, macOS asks whether CrateMate may access Apple Music. Click **Allow**.

To update later, run `git pull`, then run `scripts/build-app.sh --install` again.

## Usage

1. **Choose your DJ folder.** Use the same folder Rekordbox uses. The first scan reads every file's tags, and later scans read only what changed.
2. **Select playlists** in the sidebar. ⌘-click selects several.
3. **Review the matches.** By default, **Needs attention** shows only the songs that need a look:

   | Mark | Meaning |
   |---|---|
   | ✅ | Matched with confidence |
   | ❓ | Probably right, but worth a look, e.g. a close call between an Original and an Extended Mix |
   | ❌ | Not found in your DJ folder |

   To fix a row, choose another file from its menu, use 🔍 to search your DJ folder, or choose **Skip** to leave it out.
4. **Click Export.** Each playlist is saved as its own `.m3u8` in `~/Music/CrateMate`. You can change the folder at the bottom of the sidebar.
5. **Import into Rekordbox.** Choose **File › Import › Import Playlist**, or drag the `.m3u8` onto **Playlists**.

### Without Apple Music access

If CrateMate can't read your library, you can export a playlist yourself. In Apple Music, select the playlist and choose **File › Library › Export Playlist…** with **Format: Unicode Text**. Then open that file in CrateMate with **File › Open Playlist Export…** (⌘O).

## How matching works

For each song, CrateMate takes the title apart into its core title, the version (e.g. "Joe Remix", "Extended Mix") and any featured artists. It normalises everything to plain lowercase words. Then it scores every library file that shares a word with the title:

| Part | Weight | |
|---|---|---|
| Title | 50% | Exact match, shared words, or edit distance, whichever is highest |
| Artist | 30% | Share of artist names in common, including featured artists |
| Version | 20% | Whether both are the same remix or edit |
| Length | bonus or penalty | Up to +10% if within 3 s, −15% if more than 30 s apart |

A score of 85% or more is a match. A score of 70% or more is picked but flagged for a check. Anything lower counts as not found. A match is also flagged if a different recording scored almost as high.

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) covers the details.

## Privacy

CrateMate works entirely on your Mac. It makes no network requests and collects no analytics.

- **Reads:** your Apple Music library's metadata, and the tags of the audio files in the DJ folder you choose.
- **Writes:** the `.m3u8` files you export, and a tag cache in `~/Library/Application Support/CrateMate/`.

## Troubleshooting

<details>
<summary><b>"Couldn't read your Apple Music library"</b></summary>

Allow CrateMate in **System Settings › Privacy & Security › Media & Apple Music**, then quit and reopen it. If CrateMate isn't listed there, reset the permission so macOS asks again:

```bash
tccutil reset MediaLibrary com.bobbyf.cratemate
```

You can always fall back to a Unicode Text export (⌘O); see [Without Apple Music access](#without-apple-music-access).
</details>

<details>
<summary><b>Rekordbox imports the playlist but adds new tracks instead of linking existing ones</b></summary>

Rekordbox links an imported entry only if the path is exactly that of a file already in its collection. Make sure the DJ folder in CrateMate is the folder your Rekordbox collection points at. If a row shows the duplicate icon, choose the copy Rekordbox has.
</details>

<details>
<summary><b>A song matched the wrong file</b></summary>

Choose the right file from the row's menu, or use 🔍 to search. If the matcher keeps getting a kind of title wrong, please [open an issue](https://github.com/bflip12/cratemate/issues/new/choose). Include the Apple Music title, artist and length, plus the filename and tags of the file it should have picked.
</details>

<details>
<summary><b>New files in my DJ folder don't show up</b></summary>

CrateMate rescans when it starts. Click ↻ next to the DJ folder to rescan now, which re-reads every file's tags.
</details>

## Contributing

Bug reports, matching edge cases and pull requests are welcome. To get set up, see [CONTRIBUTING.md](CONTRIBUTING.md). For conventions, see [docs/CODE_STYLE.md](docs/CODE_STYLE.md).

## License

[MIT](LICENSE) © 2026 Bobby Filippopoulos

Apple Music is a trademark of Apple Inc. rekordbox is a trademark of AlphaTheta Corporation. CrateMate is an independent project and isn't affiliated with or endorsed by either company.
