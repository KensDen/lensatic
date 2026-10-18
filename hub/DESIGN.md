# The Lensatic field system

Lensatic 2.0.2, 18 October 2026 (first written for 2.0 the same day). The design system for the hub, the section landings, the Zero Trust guide page, the map's tokens and
the Agentic SecOps landing, and the umbrella bar on the map and the Agentic SecOps app. `hub/lensatic.css` is the one shared file;
`docs/shared/lensatic.css` is its published copy. Every page inlines it (or, for the map, carries the same values in the
tokens at the top of `web/src/styles.css`), so no page loads it over the network. `tools/check_umbrella.py` holds the map's and
the app's tokens to these values and every page to the current bar.

## Tokens

The names are the map's, so one vocabulary covers the system and the map's iOS colours (`tools/gen_ios_colors.py`) keep their names.

| Token | Light | Dark | Role |
|---|---|---|---|
| `--bg` | `#F3F4F1` | `#040817` | page ground |
| `--bg-2` | `#FFFFFF` | `#0A1128` | surfaces: cards, tiles, the top bar, the footer |
| `--bg-3` | `#E9EBE6` | `#0F1834` | the second surface: table heads, nested panels |
| `--fg` | `#0B1220` | `#EAF4FF` | text |
| `--fg-2` | `#4A5568` | `#8FA3C2` | secondary text, the plain eyebrow |
| `--line` | `#D9DCD4` | `#1A2645` | hairlines and card borders |
| `--line-strong` | `#A9AEA3` | `#2B3B62` | control edges, the neutral tile rule |
| `--accent` | `#075985` | `#45C4F4` | the primary accent: accent text, and a primary button outside a section |
| `--accent-fg` | `#FFFFFF` | `#04111C` | text on the accent |
| `--link` | `#075985` | `#73DEF6` | links |
| `--focus` | `#075985` | `#73DEF6` | the focus ring |
| `--bad` | `#B91C1C` | `#EF4444` | danger and conflict |
| `--sec-maps` | `#0F766E` | `#2DD4BF` | Framework Maps: eyebrow, tile rule, active link, primary button |
| `--sec-guides` | `#4A5D23` | `#9BE15D` | Field Guides: eyebrow, tile rule, active link, primary button |
| `--sec-playbook` | `#5E2868` | `#B273B5` | Playbook: eyebrow, tile rule, active link, primary button |
| `--on-sec-maps` | `#FFFFFF` | `#04111C` | the label on a Framework Maps primary button (2.0.2) |
| `--on-sec-guides` | `#FFFFFF` | `#04111C` | the label on a Field Guides primary button (2.0.2) |
| `--on-sec-playbook` | `#FFFFFF` | `#04111C` | the label on a Playbook primary button (2.0.2) |
| `--tile-bg` | `#0E100D` | `#161A13` | the mark tile: the compass, and the APT_UNICORN emblem since 2.0.2 |
| `--tile-fg` | `#9BE15D` | `#9BE15D` | the compass in its tile |
| `--grid` | `none` | `linear-gradient(rgba(69,196,244,0.04) 1px, transparent 1px), linear-gradient(90deg, rgba(69,196,244,0.04) 1px, transparent 1px)` | the faint grid on the hub hero (dark only) |

| Size and space | Value |
|---|---|
| `--radius` | `8px` |
| `--card-radius` | `12px` |
| `--s-1` | `4px` |
| `--s-2` | `8px` |
| `--s-3` | `12px` |
| `--s-4` | `16px` |
| `--s-5` | `24px` |
| `--s-6` | `32px` |
| `--s-7` | `48px` |
| `--s-8` | `64px` |
| `--maxw` | `68rem` |

Type: `--sans` is IBM Plex Sans and `--mono` is IBM Plex Mono, with system fallbacks.

Contrast (WCAG 2.x, both themes): light: lowest text pair 4.56 (`--sec-maps` on `--bg-3`), text on the accent 7.56, focus ring on the ground 6.85; dark: lowest text pair 4.65 (`--bad` on `--bg-3`), text on the accent 9.49, focus ring on the ground 12.84. The map's own floors (`tools/check_web.py`) and the Agentic SecOps floors
(`playbook/Validation/statics_check.cjs`) also hold.

Section buttons (2.0.2), the label on its accent: light: Framework Maps 5.47, Field Guides 7.29, Playbook 10.61; dark: Framework Maps
10.24, Field Guides 12.09, Playbook 5.46. Every pair clears AA (4.5) as the section accents already stood, so no accent was darkened
for the light theme; `tools/check_umbrella.py` holds the three pairs in both themes.

## Decisions

**Dark ground from the playbook.** The dark theme takes the Agentic SecOps app's ground and surfaces as its seed: `#040817` for the
page, `#0A1128` for surfaces and `#0F1834` for the second surface. Borders are 1px and quiet. The playbook's own borders are a
translucent blue (it makes `#151D31` over the ground); here they are solid hex, a step lighter at `#1A2645` so a card's edge still reads
on the surface, and solid so the iOS build and the contrast checks can read them. The hub hero carries the playbook's faint grid, drawn in CSS; nothing else is textured.

**A light theme that is a theme.** The map's warm paper (`#F6F2E8`) moved toward neutral, to `#F3F4F1`, so the light theme sits with
the navy dark one without going clinical. Surfaces are white and the second surface `#E9EBE6`. Text is the playbook's light-theme
ink `#0B1220`; secondary text darkened from the playbook's `#56627A` to `#4A5568` to clear 4.5 on every surface, the second one included.

**One primary accent: the playbook's blue.** `#45C4F4` on dark and `#075985` on light carry buttons and accent text everywhere. The
map gives up its green accent for it, and the green moves to Field Guides.

**Section accents mark, they never carry meaning alone.** Framework Maps is teal (`#2DD4BF` / `#0F766E`), Field Guides the compass green
from the old Lensatic accent (`#9BE15D` / `#4A5D23`), and Playbook the playbook's own purple for red, blue and purple teaming (`#B273B5` /
`#5E2868`). They appear only on eyebrows, tile rules, the active section link and (since 2.0.2) each section's primary button, and every
one of those also says the section's name in words. The purple is the playbook's plum, the one violet its identity guard allows.

**Danger stays the playbook's red.** `#EF4444` on dark. On light the playbook's `#DC2626` measures 4.37 on the light ground and 4.02 on
the second surface, so light danger is `#B91C1C`, the same red one step darker.

**Each section has its own mark, at its existing art.** Framework Maps: the Lensatic compass (`web/src/mark.svg`). Field Guides: the
slashed-zero compass from the Zero Trust guide (`guides/zero-trust/icon.svg`), which stays that guide's icon. Playbook: the APT_UNICORN
emblem (`hub/marks/apt-unicorn-emblem.webp`, the landing's own file). Marks are only resized, never redrawn. Since 2.0.2 the emblem
sits in the same dark rounded-square tile as the compass (`--tile-bg`, the mark at about 71% of the tile), so the three marks read as
one set: the compass and the emblem in the tile, and the slashed zero, whose own art is drawn on that tile. The compass stays the
parent brand on the hub header, the favicon and the hub card, and its tile keeps the map's colours (`--tile-bg`, `--tile-fg`).

**Type.** IBM Plex Sans for text; IBM Plex Mono for eyebrows, version lines, counts and code. The hub and guides index embed the
map's four Latin-1 faces; the Agentic SecOps pages keep the faces they already bundle; the Zero Trust page keeps its own.

**Chrome.** One top bar (the mark, Lensatic, the three section links, About and the theme toggle), one page header (eyebrow, H1, a
one-line standfirst), one tile (mark, title, one line, a count line, an Open button) and one footer (the version line, privacy, support,
the repository and, since 2.0.2, the rights line).
Every control is at least 44px tall. The radius is 8px for controls and 12px for cards, and spacing runs on a 4px scale. There is no
animation beyond the playbook's existing transitions. On the map and the Agentic SecOps app the bar is a slim strip above the app's
own header, so neither app's tested layout changes; the map's bar shows the name alone because the app's header below it carries the
compass.

**How the sections take it.** Every rule in the shared file is scoped to an `lx-` class, so it can sit beside any page's stylesheet.
The map copies the values into its own token block (the convention `build_web.py` and `gen_ios_colors.py` read) and inlines the file
for the bar. The Zero Trust guide inlines it and aliases its own token names (`--surface` is `--bg-2`, `--text` is `--fg`, and so on).
The Agentic SecOps landing inlines it; the app inlines it before its own stylesheet and keeps its layout and components, with its
light-theme colours moved to these values (its dark theme was already this theme's seed).

**Link-preview cards.** One family, made by `tools/make_social_card.mjs`: the page's mark, an eyebrow in the section colour, the title
and the line on the dark ground with the grid, over the same lower band on every card (the compass, Lensatic, the three section names,
the address, above a rule in the three section colours). The hub card is also the map's and the guides index's. The Playbook card was
made again in 2.0.2 with the emblem in its tile, under a new name (`playbook/social-card-v2.png`) so link previews fetch it afresh.

## Lensatic 2.0.1 and 2.0.2

**The About photo block (2.0.1).** The hub's About ends where the name comes from: the heading "Why the name" (`ui.labels.whyNameHeading`),
then the maker's compass photo beside the name story (`meta.about.nameStory`). The photo is `web/src/about-photo.jpg` embedded as a data
URI, with the map's alt text, a 1px `--line` border and the 12px card radius. From 768px the block is two columns, the photo in two
parts of five and the story in three; below that the photo stacks above the text.

**One theme toggle (2.0.2).** The umbrella bar carries one icon toggle at its end, the same on every page with the bar (the hub, the
guides index, Framework Maps, the Zero Trust guide, the Agentic SecOps landing and app): the map's half-filled circle, in a 44px square
outlined in `--line-strong`. Below 48rem it stays on the brand's row and the section links take the row beneath. A press steps through
system, light and dark; the button's accessible name and title say the state ("Theme: System"). The choice is one localStorage key,
`lensatic-theme`, read before first paint by `hub/theme-head.js` and changed by `hub/theme-bar.js`, which the bar carries. A choice the
Zero Trust page (`ztfg-theme`) or the Agentic SecOps app (`playbook-theme`) saved earlier moves to it once and those keys are removed.
The button is hidden until its script runs, so a page without script follows the system setting. The map header's icon, the Zero Trust
page's "Theme: system" pill and the app header's moon are gone. The privacy and support pages carry no bar and no script; they follow
the system setting.

**Section-tinted primary buttons (2.0.2).** A primary button takes its section's accent with its `--on-sec-*` label colour: teal on
Framework Maps, green on Field Guides (the guides index and the Zero Trust guide), purple on the Playbook landing and in the app (the
glossary button). On the hub each card's Open button takes its card's accent. Secondary buttons stay outlined. The values and their
contrast are in the tables above.

**The rights line (2.0.2, gauntlet question 33).** The hub and the guides index footers end with "Copyright 2026 Ken Connell. All rights
reserved.", the last words linked to the root `LICENSE`. The Zero Trust guide carries the same line linked to its own notice.
