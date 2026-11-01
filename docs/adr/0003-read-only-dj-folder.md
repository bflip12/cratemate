# 0003. Only ever read the DJ folder

**Status:** Accepted

## Context

rekordbox tracks every file in its collection by path. Moving, renaming or retagging a file breaks the link, and the user loses the cues, loops and beatgrids they've set on it. A tool that "tidies up" a DJ folder can do real damage to someone's sets.

## Decision

CrateMate never writes to the DJ folder. It reads tags and lengths, and writes only the exported `.m3u8` files (to a separate folder the user picks) and its own tag cache in `~/Library/Application Support/CrateMate`.

## Consequences

- Users can point CrateMate at their real collection without a backup first.
- Features that would need to change files, like fixing tags or renaming files to match, are out of scope. Problems like duplicates are reported for the user to act on in their own tools.
- Code review checks this rule on every pull request (it's in the PR template's checklist).
