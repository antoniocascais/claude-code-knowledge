---
name: latex-presentation
description: Creates impressive LaTeX Beamer presentations with modern design. Generates .tex files with theme selection, font pairing, TikZ diagrams, overlays, and best practices. Use for LaTeX slides, Beamer presentations, scaffolding decks, slide design advice, or TikZ diagram generation.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# LaTeX Presentation Skill

Generate visually impressive LaTeX Beamer presentations. Focus on .tex file generation only — never compile or run build commands.

## Workflow

1. **Understand the request** — determine what the user needs:
   - Scaffold a new presentation from scratch
   - Add/modify slides in an existing presentation
   - Generate a TikZ diagram or figure
   - Recommend themes, fonts, or packages
   - Review slides for best practices

2. **Ask clarifying questions** if not provided:
   - Topic/purpose of the presentation
   - Audience (academic, corporate, tech talk, casual)
   - Preferred aesthetic (minimalist, dark, colorful, formal)
   - Approximate number of slides
   - Whether math-heavy or visual-heavy

3. **Read `references/design-guide.md`** for detailed theme lists, package tables, font pairings, and code patterns before generating.

4. **Generate .tex files** following the design principles and patterns from the guide.

## Default Stack (override if user prefers otherwise)

- Engine target: LuaLaTeX
- Theme: Metropolis (`\usetheme{metropolis}`)
- Aspect ratio: 16:9 (`aspectratio=169`)
- Fonts: Fira Sans + Fira Code + Fira Math
- Always include: `\setbeamertemplate{navigation symbols}{}`
- Always include: `appendixnumberbeamer`

## Key Design Rules

- **One idea per slide** — split if needed
- **3-4 colors max** — primary, accent, neutrals
- **No Computer Modern** — always set modern fonts
- **Left-align text** — center only titles and single statements
- **6x6 rule** — max 6 lines, max 6 words per line
- **Font size hierarchy** — Title > Section > Body > Caption, consistent across list levels
- **Generous whitespace** — don't fill every pixel
- Use `[fragile]` on any frame containing minted/verbatim
- Use `tcolorbox` instead of default Beamer blocks when visual quality matters
- Prefer TikZ/PDF vector graphics over raster images

## Scaffold Structure

When creating a new presentation, generate this file structure:

```
presentation/
  main.tex          # document class, preamble, \input calls
  preamble.tex      # packages, theme config, custom commands
  sections/
    01-title.tex
    02-intro.tex
    ...
    99-backup.tex   # appendix/backup slides
  figures/          # directory for images
```

Split into sections for version-control friendliness. One sentence per line in .tex source.

## TikZ Diagrams

When generating TikZ:
- Use `positioning`, `arrows.meta`, `shapes` libraries
- Support Beamer overlays (`<1->`, `<2->`) for incremental reveals
- Use `remember picture, overlay` for absolute positioning
- Match colors to the presentation's theme palette
- Keep diagrams readable — don't overcrowd

## Theme Selection Guide

Match theme to context:
- **Academic/research**: Metropolis, Moloch, Pascal Michaillat's minimalist
- **Tech/engineering**: Nord, Gotham, Focus
- **Corporate**: Execushares, pure-minimalistic
- **Math-heavy**: BlackBoard, Arguelles
- **Creative/visual**: Fancyslides, Trigon
- **Dark mode**: Nord dark, Metropolis dark, Kalgan

## Anti-Patterns to Flag

If reviewing existing slides, flag:
- Default Beamer theme with no customization
- Navigation symbols still visible
- Walls of text (>6 lines)
- Computer Modern font
- 4:3 aspect ratio (unless intentional)
- Low-res raster images where vectors would work
- Inconsistent colors or font sizes
- Missing `[fragile]` on code frames
