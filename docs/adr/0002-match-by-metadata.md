# 0002. Match songs by metadata, not by Apple Music's file paths

**Status:** Accepted

## Context

Apple Music can export a playlist as M3U, but it only writes paths for songs stored on the Mac. With an iCloud library most songs have no local file, so the export is often empty. Even local files are Apple Music's copies, usually not the files a DJ has prepared in rekordbox with cues and beatgrids.

What a DJ wants is a rekordbox playlist that points at the files already in their collection.

## Decision

Ignore Apple Music's file locations. For each song, match its artist, title, version and length against the tags (or, when untagged, the filenames) of the audio files in a DJ folder the user chooses. Score candidates on title (50%), artist (30%) and version (20%), with a bonus or penalty for length, and classify each result as matched, worth a check, or not found. The scoring is described in [ARCHITECTURE.md](../ARCHITECTURE.md#scoring).

## Consequences

- It works for cloud-only libraries, which is the main reason the app exists.
- It picks the DJ's own copy, so rekordbox links to existing tracks and keeps their cues.
- Matching can be wrong. The app shows every result and lets the user change or skip it before exporting, and close calls are flagged rather than guessed.
- Thresholds are tuned on a generated test library. Each real-world mismatch should become a test before the scoring changes.
