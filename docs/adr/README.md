# Architecture decision records

Each file here records one decision that shapes CrateMate: the situation, what was decided, and what follows from it. They explain *why* the code and the project look the way they do. [ARCHITECTURE.md](../ARCHITECTURE.md) explains *how* it works today.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-record-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-match-by-metadata.md) | Match songs by metadata, not by Apple Music's file paths | Accepted |
| [0003](0003-read-only-dj-folder.md) | Only ever read the DJ folder | Accepted |
| [0004](0004-offline-no-dependencies.md) | No network access and no third-party dependencies | Accepted |
| [0005](0005-m3u8-absolute-paths.md) | Export extended M3U in UTF-8 with absolute paths | Accepted |
| [0006](0006-command-line-tools-build.md) | Build with SwiftPM and the Command Line Tools only | Accepted |
| [0007](0007-ad-hoc-signed-releases.md) | Ship ad-hoc signed DMGs from GitHub Releases | Accepted |
| [0008](0008-system-accent-colour.md) | Use the system accent colour inside the app | Accepted |
| [0009](0009-static-website.md) | Build the website as static HTML with no build step | Accepted |

## Writing a new one

Copy [template.md](template.md) to the next number with a short slug, e.g. `0010-rekordbox-xml-export.md`, fill it in, and add it to the table above in the same pull request as the change it describes.

- Keep it short: a reader should get the decision in a minute.
- Don't edit an accepted ADR's decision. If it changes, write a new ADR that supersedes it, and set the old one's status to `Superseded by [00NN](00NN-slug.md)`.
- Statuses: Proposed, Accepted, Superseded, Deprecated.
