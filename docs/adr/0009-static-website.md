# 0009. Build the website as static HTML with no build step

**Status:** Accepted

## Context

The project website has a handful of pages that change rarely, mostly at releases. A site generator or framework would add dependencies, a build step and upkeep to a project that otherwise has none, and the app's privacy promise should hold for its website too.

## Decision

- `site/` holds plain HTML and one stylesheet, with no JavaScript, no build step, no third-party requests and no analytics. The Geist font is self-hosted.
- `.github/workflows/pages.yml` deploys `site/` to GitHub Pages when it changes on `main`.

## Consequences

- Anyone can edit a page in a text editor and preview it with `python3 -m http.server -d site`.
- Pages load fast and work without JavaScript.
- The header and footer are repeated on every page, so changing them means editing each page.
- The version number and download size are written by hand and updated at each release.
