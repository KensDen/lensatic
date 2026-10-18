# The Lensatic field system

Lensatic 2.0, 18 October 2026. The design system for the hub, the section landings, the Zero Trust guide page, the map's tokens and
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
| `--accent` | `#075985` | `#45C4F4` | the primary accent: buttons, accent text |
| `--accent-fg` | `#FFFFFF` | `#04111C` | text on the accent |
| `--link` | `#075985` | `#73DEF6` | links |
| `--focus` | `#075985` | `#73DEF6` | the focus ring |
| `--bad` | `#B91C1C` | `#EF4444` | danger and conflict |
| `--sec-maps` | `#0F766E` | `#2DD4BF` | Framework Maps: eyebrow, tile rule, active link |
| `--sec-guides` | `#4A5D23` | `#9BE15D` | Field Guides: eyebrow, tile rule, active link |
| `--sec-playbook` | `#5E2868` | `#B273B5` | Playbook: eyebrow, tile rule, active link |
| `--tile-bg` | `#0E100D` | `#161A13` | the compass tile |
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
`#5E2868`). They appear only on eyebrows, tile rules and the active section link, and every one of those also says the section's name
in words. The purple is the playbook's plum, the one violet its identity guard allows.

**Danger stays the playbook's red.** `#EF4444` on dark. On light the playbook's `#DC2626` measures 4.37 on the light ground and 4.02 on
the second surface, so light danger is `#B91C1C`, the same red one step darker.

**Each section has its own mark, at its existing art.** Framework Maps: the Lensatic compass (`web/src/mark.svg`). Field Guides: the
slashed-zero compass from the Zero Trust guide (`guides/zero-trust/icon.svg`), which stays that guide's icon. Playbook: the APT_UNICORN
emblem (`hub/marks/apt-unicorn-emblem.webp`, the landing's own file). Marks are only resized, never redrawn. The compass stays the
parent brand on the hub header, the favicon and the hub card, and its tile keeps the map's colours (`--tile-bg`, `--tile-fg`).

**Type.** IBM Plex Sans for text; IBM Plex Mono for eyebrows, version lines, counts and code. The hub and guides index embed the
map's four Latin-1 faces; the Agentic SecOps pages keep the faces they already bundle; the Zero Trust page keeps its own.

**Chrome.** One top bar (the mark, Lensatic, the three section links, About), one page header (eyebrow, H1, a one-line standfirst),
one tile (mark, title, one line, a count line, an Open button) and one footer (the version line, privacy, support, the repository).
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
the address, above a rule in the three section colours). The hub card is also the map's.
