# 0010. Remember picks by song, not by playlist

**Status:** Accepted

## Context

Without saved picks, every fix in the review list is lost when the app quits or the DJ folder is rescanned, so re-exporting a playlist means fixing the same rows again. DJs also put the same song in many playlists, and the right file for a song doesn't depend on which playlist it's in.

Picks could be keyed by Apple Music's track ID, by playlist and row, or by the song's metadata. Track IDs don't exist for playlists opened from a text export, and row positions change whenever a playlist is edited.

## Decision

Save each decision in `~/Library/Application Support/CrateMate/picks.json`, keyed by the song's normalised artist and title. A decision is a chosen file path or a skip. A pick made in one playlist applies to the same song everywhere, straight away and in later sessions.

A saved file is used only while it's still in the DJ folder. A skip is used only while the matcher's best file is the one it was when the song was skipped, so a song added to the DJ folder later comes back for review instead of staying left out.

## Consequences

- Fixing a song once fixes it in every playlist, including ones exported later.
- Two different songs with the same artist and title share a pick. That's rare, and the user can still change the row.
- Editing a song's title or artist in Apple Music makes it a new song to CrateMate, so it's reviewed again.
- The file sits next to the tag cache, outside the DJ folder, as [ADR 0003](0003-read-only-dj-folder.md) requires. Settings has Forget All Picks… to clear it.
