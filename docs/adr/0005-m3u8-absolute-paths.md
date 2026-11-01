# 0005. Export extended M3U in UTF-8 with absolute paths

**Status:** Accepted

## Context

The playlist has to get into rekordbox and link to tracks already in the collection. rekordbox can import M3U/M3U8 playlists and rekordbox XML. When it imports an M3U, it links an entry to an existing collection track only if the path matches exactly.

## Decision

Export one `.m3u8` per playlist: extended M3U, UTF-8, LF line endings, with an `#EXTINF` line (length and "Artist - Title") and the file's absolute path for each track.

## Consequences

- Import is one menu command in rekordbox, and existing tracks keep their cues and grids.
- UTF-8 handles accents and non-Latin titles.
- The DJ folder in CrateMate must be the one rekordbox uses, or rekordbox adds new tracks instead of linking. The README's troubleshooting covers this.
- Absolute paths tie the playlist to this Mac's folder layout, which is fine for a file that's imported right away.
- rekordbox XML would allow more (for example, writing straight into the collection), but it's a much bigger format and isn't needed for playlists.
