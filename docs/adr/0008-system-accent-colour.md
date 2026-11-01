# 0008. Use the system accent colour inside the app

**Status:** Accepted

## Context

CrateMate's brand colours are forest green and yellow. The review list uses green for matched, orange for worth a check and red for not found. A forest-tinted app would put the brand colour next to, and easily confused with, the status colours.

## Decision

Inside the app, use the user's system accent colour and the system font, like most Mac apps. The brand shows in the app icon, the first-run screen, the README and the website, not in custom chrome.

## Consequences

- Status colours stay unambiguous.
- The app looks and behaves like a native Mac app and respects the user's settings.
- The app itself carries less brand character. That's accepted, since the icon carries it in the Dock and Finder.
