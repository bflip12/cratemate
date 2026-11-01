# CrateMate brand

<img src="lockup-horizontal-on-light.svg" width="360" alt="CrateMate logo">

CrateMate is an organisation tool for a DJ's record collection: it sorts and files, it doesn't make music. The brand should feel analog and printed, calm and a little bit heady. Not childish, not techy, and nothing that looks like a music-making app (waveforms, knobs, faders, play buttons).

[BRIEF.md](BRIEF.md) explains the reasoning behind these choices and the directions that were tried and rejected.

## Name

**CrateMate**, one word, capital C and M, in running text, menus and the app bundle (`CrateMate.app`). The wordmark sets it in lowercase, `cratemate`, with "mate" in a second colour. Don't write "Crate Mate", "Cratemate" or "CRATEMATE".

## Logo

The mark is two sets of rings printed in two inks, like a risograph. One set is the song in Apple Music, the other is your copy in the DJ folder, and where they line up the inks overprint into a moiré.

| File | Use |
|---|---|
| [lockup-horizontal-on-light.svg](lockup-horizontal-on-light.svg), [on-dark](lockup-horizontal-on-dark.svg) | The default logo. |
| [lockup-stacked-on-light.svg](lockup-stacked-on-light.svg), [on-dark](lockup-stacked-on-dark.svg) | Square-ish spaces. |
| [wordmark-on-light.svg](wordmark-on-light.svg), [on-dark](wordmark-on-dark.svg) | Where the mark is already shown nearby. |
| [mark-on-light.svg](mark-on-light.svg), [on-dark](mark-on-dark.svg) | The rings alone, e.g. as an avatar. |
| [`../assets/icon.png`](../assets/icon.png) | The app icon, 512 px. The `.icns` is in `Resources/`. |
| [`../assets/social.png`](../assets/social.png) | The GitHub social preview, 1280 × 640. |

The wordmark is Geist SemiBold converted to outlines, so no font is needed to use it.

- Keep clear space around the logo of at least the height of the "m".
- Don't recolour, stretch, rotate or outline it, and don't add effects. The second ink overprints the first (multiply); keep that, not plain transparency.
- Use the `on-light` files on Paper or white and the `on-dark` files on Deep forest or near-black.

## Colour

| Name | Hex | Use |
|---|---|---|
| Paper | `#F2ECDC` | Backgrounds, the icon's sheet |
| Forest | `#2F5A49` | First ink; "mate" on light backgrounds |
| Yellow | `#F5D000` | Second ink; "mate" on dark backgrounds |
| Deep forest | `#1E3A2F` | Text on light backgrounds; dark backgrounds |

Yellow is never text on Paper or white; it's too faint. Inside the app there's no brand accent colour: the app follows the user's system accent, because Forest and Yellow are too close to the green (matched) and orange (worth a check) status colours.

## Type

[Geist](https://vercel.com/font) (OFL), SemiBold for headings and the wordmark, Regular or Medium for text, tracked slightly tight. Use it for brand material: the README header, the social preview and the website. The app itself uses the system font.

## Voice

Plain and warm, a little bit of record-shop talk, never cute. Say what happened, then what to do. For example: "23 of 25 in the crate. 2 still out there."

## Rebuilding the assets

- The app icon: edit `scripts/make-icon.swift`, then run `scripts/make-icon.sh`.
- The wordmark, lockups and social preview were generated once from Geist's outlines. Edit the SVGs directly; the colours and the `isolation`/`mix-blend-mode` settings are plain attributes.
