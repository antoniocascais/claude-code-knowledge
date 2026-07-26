---
name: visual-explainer
description: Renders conversation content (brainstorms, design discussions, walls of text) as a single self-contained, visually-structured HTML page that is easy to grasp at a glance. Use when the user says "visualize this", "make this visual", "turn this into a page", "make a visual explainer", "render as HTML", "this is a wall of text", "hard to read", "make a visual summary", or wants a friendlier visual representation of a technical discussion, architecture, concept explainer, or set of decisions/tradeoffs.
allowed-tools:
  - Read
  - Write
argument-hint: [optional topic or focus]
---

# Visual Explainer

Turn dense conversation content into ONE self-contained light-themed HTML page optimized for fast visual comprehension. The audience is a senior DevOps/SRE engineer — technical/architecture rendering matters most.

## Output contract (non-negotiable)

- **One file.** A single `.html` with ALL CSS and JS inlined. Zero external dependencies — no CDN links, no web fonts pulled over the network, no JS libraries. Must open by double-clicking.
- **Location.** Write to `/tmp/` with a descriptive kebab-case filename, e.g. `/tmp/k8s-ingress-tradeoffs.html`.
- **Diagrams** are built with inline SVG or styled HTML/CSS — never an external diagramming lib.
- After writing, report the absolute file path. Do NOT auto-open or start a server.

## Workflow

1. **Source the content.** By default, use the relevant content from the current conversation (the brainstorm/wall-of-text just produced). If the user points at a file, Read it. Use `$ARGUMENTS` as a topic/focus hint if provided.
2. **Decompose into chunks.** Break the content into logical sections. For each chunk, pick the best visual format (see mapping below).
3. **Build from the design system.** Start from `assets/template.html` — it has the full inline CSS design system and JS for tabs/accordions. Copy component patterns from it and from `references/content-shapes.md`. Do not invent a new style; reuse the system so output is consistent.
4. **Adapt density.** Use collapsible `<details>` accordions or tabs where they cut clutter (long detail, alternatives, deep-dives). Keep content static and visible where scanning is better (summaries, key tables, the main diagram).
5. **Lead with a summary.** Top of page = a short orienting summary + key-insight callout(s). Then drill into detail. Highlight key terms inline.
6. **Write + report.** Write the file to `/tmp/`, then give the user the path.

## Picking the right visual format

Match each content chunk to a format. Full snippets in `references/content-shapes.md`.

| Content shape | Use |
|---|---|
| System/architecture, data flow, request path | Inline-SVG or CSS box-and-arrow **diagram** |
| Sequential process, runbook, pipeline stages | **Stepper** / numbered flow |
| Options, tradeoffs, "X vs Y", decision | **Comparison table** or pros/cons grid + recommendation callout |
| Distinct concepts / components at same level | **Card grid** |
| Caveats, gotchas, key takeaways, warnings | **Callout boxes** (note / tip / warning / key-insight) |
| Hierarchy, taxonomy, mind-map | Nested CSS tree or radial **mind-map** |
| Long detail behind a summary | `<details>` **accordion** or **tabs** |
| Definitions / mental models | Card with highlighted **key term** + short body |

## Design principles

- **Light, clean, minimal.** White/near-white background, generous whitespace, restrained accent palette, strong typography hierarchy. Docs-site feel, not a dashboard.
- **Scannable.** A reader should grasp the structure in ~5 seconds: clear headings, a sticky/visible section nav or TOC for longer pages, consistent component styling.
- **Color carries meaning.** Reserve accent colors for callout semantics (info/tip/warn/insight) and diagram emphasis — don't decorate randomly.
- **Self-contained fonts.** Use a system font stack; never fetch web fonts.

See `references/content-shapes.md` for the component library and `assets/template.html` for the base.
