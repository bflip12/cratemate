# Changelog

All notable changes to CrateMate are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

The first public release will be 0.1.0.

### Added

- A native SwiftUI app that reads Apple Music playlists, including cloud-only ones, through `iTunesLibrary`.
- Metadata matching against a local DJ folder, scored on title, artist, version and track length.
- A review list with a "Needs attention" filter, alternative candidates, DJ folder search and skip. Rows leave the filter as you decide on them, with ✓ to keep a suggested match and Accept All for the rest of a playlist, and the header counts what's left. Edit › Undo (⌘Z) undoes each decision.
- Rows that need a check say why, e.g. "Different version, 0:44 longer" or "Another file scores 99%: …". The core's `differences(_:_:)` works it out.
- A playlist with none of its songs in the DJ folder shows one message, with Copy Song List, instead of a row of red for every song. Playlists with nothing to export are left out of an export, and the alert says so.
- A repeat icon on a row whose file an earlier song in the same playlist already uses.
- A labelled Export button ("Export 3 Playlists" when several are selected), and the window title shows the selected playlist and how many of its songs will be exported.
- Remembered picks: a file you choose or a song you skip applies to that song in every playlist and is kept between launches. Settings has Forget All Picks… to clear them.
- Duplicate detection for the same recording stored more than once in the DJ folder. Clicking the duplicate icon shows every copy in Finder.
- Show in Finder in a row's shortcut menu, for the file it's matched to. CrateMate only shows files; it never moves or deletes them.
- `.m3u8` export with absolute paths, ready for Rekordbox's Import Playlist.
- A fallback for Apple Music's Unicode Text playlist export (⌘O).
- Collapsible playlist folders in the sidebar, collapsed by default, with a Settings window (⌘,) to start them expanded instead. A folder's shortcut menu has Select All Playlists in Folder.
- Every playlist is matched after a scan, and the sidebar shows how many of its songs will be exported, e.g. 183/185.
- A tag cache, so only new or changed files are read after the first scan.
- A download: a universal app for Apple silicon and Intel Macs in a drag-to-Applications DMG, published to GitHub Releases by `.github/workflows/release.yml` when a version tag is pushed.
- The CrateMate name, app icon, logo and wordmark. The icon is drawn by `scripts/make-icon.sh`; the rest is in `docs/brand`.

### Changed

- Renamed from am2rb to CrateMate. The bundle identifier is now `com.bobbyf.cratemate`, so macOS asks for Apple Music access again. The DJ folder and export folder settings carry over; the tag cache moves to `~/Library/Application Support/CrateMate` and is rebuilt on the first scan. Exports now go to `~/Music/CrateMate` by default.

[Unreleased]: https://github.com/bflip12/cratemate/commits/main
