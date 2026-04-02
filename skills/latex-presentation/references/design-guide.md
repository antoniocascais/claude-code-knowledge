# Creating Cool & Impressive LaTeX Presentations

A comprehensive guide compiled from web research and knowledge base.

---

## 1. Foundation Setup

### Engine & Aspect Ratio

- **LuaLaTeX** (preferred) or XeLaTeX for modern font access via `fontspec` + `unicode-math`
- **16:9 aspect ratio** is the modern default: `\documentclass[aspectratio=169]{beamer}`
  - Exception: Pascal Michaillat argues 4:3 forces one-idea-per-slide discipline and works on all projectors/tablets
- TeX Live 2025 defaults to PDF 1.7 format

### Recommended Starter Stack

| Component | Choice |
|---|---|
| Engine | LuaLaTeX |
| Theme | Metropolis or Moloch |
| Fonts | Fira Sans + Fira Code + Fira Math |
| Diagrams | TikZ + pgfplots |
| Code blocks | minted + tcolorbox |
| Icons | fontawesome5 |
| Presenter | pdfpc or pympress |
| Build | `latexmk -lualatex -shell-escape` |

---

## 2. Design Principles

### Color

- **3-4 colors max**: one primary, one accent, one or two neutrals
- Use color for **meaning**, not decoration
- Dark themes are trending: `\metroset{background=dark}` in Metropolis
- Contrast ratio must be high (WCAG AA: 4.5:1 minimum) - test on actual projector
- Steal palettes from coolors.co, Tailwind CSS, or Material Design
- Minimalist academic approach: **grayscale text only**, reserve color for figures and alerts

### Typography

- **Ditch Computer Modern** - it screams "default LaTeX"
- Font size hierarchy: Title > Section > Body > Caption
- Minimum projected: ~20pt body, ~28pt titles
- Keep one font size across all list levels (don't shrink nested items)
- Line spacing: 150% of point size
- Use `\sbseries` / `\textsb{}` for semibold emphasis instead of full bold

### Layout

- **One idea per slide** - if you need two, use two slides
- **Generous whitespace** - don't fill every pixel
- Left-aligned text reads easier than centered (center only titles/single statements)
- Use the squint test: blur the slide - can you still see the structure?

### Remove Clutter

```latex
\setbeamertemplate{navigation symbols}{}  % kill useless nav buttons
```

No headers, no footers, no bright bullet points. They distract from the message.

---

## 3. Best Themes

### Tier 1: Modern Essentials

| Theme | Description | Source |
|---|---|---|
| **[Metropolis](https://github.com/matze/mtheme)** | The gold standard. Clean, flat, progress bar, dark mode. Uses Fira Sans | CTAN / TeX Live |
| **[Moloch](https://github.com/jolars/moloch)** | Fork/successor of Metropolis, actively maintained, bug fixes | CTAN |
| **[Focus](https://github.com/elauksap/focus-beamertheme)** | Minimalist, emphasis on content, dark/light variants | GitHub |
| **[Gotham](https://gitlab.com/RomainNOEL/beamertheme-gotham)** | LaTeX3-powered extension of Metropolis - more flexible | CTAN |

### Tier 2: Strong Alternatives

| Theme | Description |
|---|---|
| **[Nord](https://github.com/junwei-wang/beamertheme-nord)** | Arctic blue-gray palette, dark/light variants, trendy in tech |
| **[Trigon](https://github.com/Music-Hub-Code/beamertheme-trigon)** | Geometric design with triangular elements |
| **[Arguelles](https://github.com/piazzai/arguelles)** | Typographic beauty using Alegreya font family |
| **[pure-minimalistic](https://github.com/kai-tub/latex-beamer-pure-minimalistic)** | Light/dark mode support, extreme minimalism |
| **[awesome-beamer](https://github.com/LukasPietzschmann/awesome-beamer)** | Light, modern, minimal |
| **[Auriga](https://github.com/anishathalye/auriga)** | Clean, academic-friendly |
| **[Execushares](https://github.com/FuzzyWuzzie/Beamer-Theme-Execushares)** | Corporate/startup feel |

### Tier 3: Specialty

| Theme | Description |
|---|---|
| **[BlackBoard](https://github.com/kmaed/kmbeamer/)** | Mimics a blackboard - great for math talks |
| **[DarkConsole](https://github.com/kmaed/kmbeamer/)** | Terminal/console aesthetic |
| **[Kalgan](https://github.com/kartikprabhu/Kalgan-Mule-template)** | Sleek dark theme |
| **[Fancyslides](https://www.latextemplates.com/cat/presentations)** | Large fonts, background images, translucent circles/rectangles |
| **[Snowdrop (Beamer Atelier)](https://beameratelier.com/)** | Premium academic theme with progress navigation |
| **[Pascal Michaillat's Minimalist](https://pascalmichaillat.org/c/)** | Grayscale academic, Source Sans Pro, designed for research talks |

### Theme Discovery Resources

- **[Ultimate Beamer Theme List](https://github.com/martinbjeldbak/ultimate-beamer-theme-list)** - community collection with PDF previews
- **[Overleaf Beamer Gallery](https://www.overleaf.com/gallery/tagged/beamer)** - ready-to-use templates
- **[Beamer Theme Gallery](https://deic.uab.cat/~iblanes/beamer_gallery/)** - visual previews of built-in themes
- **[Beamer Theme Matrix](https://hartwork.org/beamer-theme-matrix/)** - visual matrix of ALL built-in theme + color theme combos
- **[Beamer Atelier](https://beameratelier.com/)** - teaching-first design studio
- **[CTAN presentation topic](https://ctan.org/topic/presentation)** - definitive package listing

---

## 4. Font Recommendations

### Sans-Serif (primary for slides)

| Font | Notes |
|---|---|
| **Fira Sans** | Metropolis default. Mozilla. Excellent weight range. Free |
| **Source Sans Pro** | Adobe open-source workhorse. Very readable. Free |
| **Inter** | Modern UI font, optimized for screens. Free |
| **Roboto** | Google. Includes Condensed variant for tight slides. Free |
| **Lato** | Warm, friendly. Good for informal talks. Free |
| **Montserrat** | Geometric, good for headings. Free |
| **Alegreya Sans** | Humanist, pairs with Arguelles theme. Free |

### Monospace (for code)

| Font | Notes |
|---|---|
| **Fira Code** | Ligatures, pairs with Fira Sans. Free |
| **JetBrains Mono** | Designed for IDEs, excellent readability. Free |
| **Iosevka** | Narrow - fits more code per slide. Free |
| **Source Code Pro** | Pairs with Source Sans. Free |

### Math Fonts

| Setup | Notes |
|---|---|
| `unicode-math` + Fira Math | Pairs with Fira Sans / Metropolis |
| `unicode-math` + Libertinus Math | Pairs with Libertinus text |
| `unicode-math` + STIX Two Math | Best for heavy math content |
| Euler (via `eulervm`) | Non-italic math, great for academic minimalism |

### Setup Example (LuaLaTeX)

```latex
\usepackage{fontspec}
\usepackage{unicode-math}
\setsansfont{Fira Sans}[BoldFont={Fira Sans Bold}, ItalicFont={Fira Sans Italic}]
\setmonofont{Fira Code}[Scale=0.85]
\setmathfont{Fira Math}
```

---

## 5. Must-Have Packages

### Visual & Layout

| Package | Purpose |
|---|---|
| `tcolorbox` | Beautiful colored boxes - replaces basic Beamer blocks |
| `tikz` / `pgf` | Programmatic diagrams, flowcharts, illustrations |
| `pgfplots` | Publication-quality data plots, reads CSV directly |
| `smartdiagram` | Quick bubble/flow/circular diagrams with minimal code |
| `fontawesome5` | Icon glyphs: `\faGithub`, `\faDocker`, `\faCloud` |
| `adjustbox` | Auto-fit images/tables to slide dimensions |
| `textpos` | Absolute positioning - essential for full-bleed layouts |
| `contour` | Text outlines over images |
| `qrcode` | QR codes for links on final slide |
| `appendixnumberbeamer` | Stops numbering in appendix (backup slides) |

### Code

| Package | Purpose |
|---|---|
| `minted` | Syntax highlighting via Pygments (needs `-shell-escape`) |
| `tcolorbox` + `minted` | Gold standard: framed code blocks with backgrounds |
| `listings` | Simpler alternative (no external deps) |
| `algorithm2e` / `algorithmicx` | Pseudocode typesetting |

### Icons & Symbols

| Package | Purpose |
|---|---|
| `fontawesome5` | 1,500+ icons: `\faGithub`, `\faDocker`, `\faAws` |
| `academicons` | Academic: ORCID, Google Scholar, arXiv |
| `ccicons` | Creative Commons license icons |
| `twemojis` | Twitter-style emoji as images |

### Math & Science

| Package | Purpose |
|---|---|
| `mathtools` | Superset of `amsmath` - better alignment, paired delimiters |
| `siunitx` | Proper SI unit typesetting, decimal alignment in tables |
| `glossaries-extra` | Acronym management for consistency |

### Tables

| Package | Purpose |
|---|---|
| `booktabs` | Professional rules (`\toprule`, `\midrule`). Never use vertical lines |
| `siunitx` | Number/unit formatting, decimal alignment |

### Animation & Media

| Package | Purpose |
|---|---|
| `animate` | Frame-by-frame PDF animations (Acrobat) |
| `media9` / `multimedia` | Embed video/audio |
| `latexpresents` | Media-friendly: auto-sizing images/videos, faux fullscreen |

---

## 6. Advanced Techniques

### Overlays & Progressive Reveal

```latex
% Step-by-step reveal
\begin{itemize}
  \item<1-> First point
  \item<2-> Second point (appears on click)
  \item<3-> Third point
\end{itemize}

% Highlight current, dim others
\begin{itemize}[<+->]
  \item<alert@+> Highlighted when it appears
\end{itemize}

% Conditional content
\only<2>{Visible only on slide 2}
\visible<2->{Takes space but invisible until slide 2}
```

### TikZ Integration (The Power Move)

TikZ diagrams with overlays for incremental builds:

```latex
\begin{tikzpicture}
  \node<1->[draw, rounded corners] (a) {Step 1};
  \node<2->[draw, rounded corners, right=of a] (b) {Step 2};
  \draw<2->[->, thick] (a) -- (b);
  \node<3->[draw, rounded corners, right=of b] (c) {Step 3};
  \draw<3->[->, thick] (b) -- (c);
\end{tikzpicture}
```

Annotating equations with TikZ nodes - add colored labels pointing to parts of formulas.

### Full-Bleed Background Images

```latex
{
\usebackgroundtemplate{%
  \includegraphics[width=\paperwidth,height=\paperheight]{photo.jpg}}
\begin{frame}[plain]
  \vfill
  \begin{beamercolorbox}[sep=1em, wd=0.6\paperwidth]{title}
    \Large\textbf{\textcolor{white}{Text Over Image}}
  \end{beamercolorbox}
  \vfill
\end{frame}
}
```

### Gradient Backgrounds

```latex
\setbeamertemplate{background}{
  \begin{tikzpicture}[remember picture, overlay]
    \shade[left color=blue!40, right color=purple!40]
      (current page.south west) rectangle (current page.north east);
  \end{tikzpicture}
}
```

### Sequential Figures (Animation Effect)

```latex
\includegraphics<1>[scale=0.3,page=1]{figures.pdf}%
\includegraphics<2>[scale=0.3,page=2]{figures.pdf}%
\includegraphics<3>[scale=0.3,page=3]{figures.pdf}%
```

### Beamer Theme Layering

Mix 4 independent theme layers for unique combinations:
- **Presentation themes**: overall layout
- **Color themes**: beaver, crane, dolphin, whale, etc.
- **Inner themes**: circles, rectangles, rounded
- **Outer themes**: miniframes, sidebar, tree, split

```latex
\usetheme{Madrid}
\usecolortheme{crane}
\useinnertheme{rounded}
\useoutertheme{miniframes}
```

---

## 7. Image Best Practices

### Format Priority

1. **PDF** - vector, scales perfectly (TikZ outputs PDF natively)
2. **SVG** - convert via Inkscape: `inkscape --export-type=pdf input.svg`
3. **PNG** - rasters at 150+ DPI (300 DPI for handouts)
4. **JPG** - photos only (lossy kills text/diagrams)

### SVG Workflow

```latex
\usepackage{svg}  % requires inkscape on PATH + -shell-escape
\includesvg[width=\textwidth]{diagram}
```

### Diagrams from External Tools

- **draw.io / diagrams.net** - export as PDF, include directly
- **Mermaid** - `mmdc` CLI renders to PDF/SVG, then include
- **PlantUML** - export to PDF/SVG
- **Inkscape "Save as LaTeX+PDF"** - exports SVG as TikZ-like code

### Tips

- Use `\graphicspath{{./images/}{./figures/}}` to organize
- `\adjustimage{max width=\textwidth, max height=0.7\textheight}{file}` for auto-fit
- Always prefer vector (TikZ/PDF) over raster screenshots for diagrams
- Semi-transparent overlay for text readability over images:
  ```latex
  \begin{tikzpicture}[remember picture, overlay]
    \fill[black, opacity=0.5] (current page.south west)
      rectangle (current page.north east);
  \end{tikzpicture}
  ```

---

## 8. Workflow & Tools

### Editors

| Tool | Best for |
|---|---|
| **VS Code + LaTeX Workshop** | Best overall: SyncTeX, snippets, live preview, linting |
| **Overleaf** | Collaboration, zero setup, now with AI assistant |
| **Neovim + VimTeX** | Terminal users. LuaSnip for snippets |
| **TeXstudio** | Dedicated IDE, good for beginners |

### Build Tools

| Tool | Notes |
|---|---|
| **latexmk** | Gold standard. `latexmk -pvc -lualatex` for continuous preview |
| **Tectonic** | Rust-based, auto-downloads packages, good for CI |
| **arara** | Directive-based (build recipe in comments) |

### Presenter Tools

| Tool | Notes |
|---|---|
| **pdfpc** | Dual-screen with notes, timer, overview |
| **pympress** | Cross-platform, supports embedded media |

### Version Control

- Use the [standard LaTeX .gitignore](https://github.com/github/gitignore/blob/main/TeX.gitignore)
- **One sentence per line** in `.tex` source — makes git diffs readable and merges sane
- Split frames into separate files: `\input{sections/intro.tex}` to reduce merge conflicts
- Git LFS for large binary images
- Keep original source files (SVG, draw.io XML) alongside generated PDFs
- `\usepackage{gitinfo2}` to stamp commit hash on slides
- **`latexdiff`** for generating highlighted diff PDFs between revisions
- Store `.latexmkrc` in repo for reproducible builds

### CI/CD

- GitHub Actions: `xu-cheng/latex-action` or Tectonic Docker image
- Push compiled PDF as release artifact or to GitHub Pages

---

## 9. Common Mistakes

### Content

1. **Too much text** - max 6 lines, 6 words per line (6x6 rule)
2. **Too many bullet points** - replace with diagrams/images/single statements
3. **Reading slides verbatim** - slides are visual aids, not a teleprompter

### Design

4. **Using default Beamer unchanged** - screams "zero effort"
5. **Keeping navigation symbols** - useless when projected
6. **Low-resolution images** - use vectors when possible
7. **Too many animations/transitions** - subtle reveal = good; star-wipe = 2003 PowerPoint
8. **Inconsistent styling** across slides

### Technical

9. **pdfLaTeX when you need modern fonts** - use LuaLaTeX
10. **Forgetting `[fragile]` on frames with minted/verbatim** - classic cryptic error
11. **4:3 in 2026** - most screens are 16:9 now (unless deliberately minimalist)
12. **Not testing on actual projector** - colors look different projected
13. **Ignoring PDF viewer compatibility** for animations

### Structural

14. **No outline slide** - audiences need a roadmap
15. **No takeaway slide** - end with key messages, not just "Questions?"
16. **Too many slides** - ~1-2 min per slide rule

---

## 10. Non-LaTeX Alternatives Worth Knowing

| Tool | Notes |
|---|---|
| **Typst + Polylux/Touying** | Modern typesetting, dramatically faster compilation, native presentation support. Maturing fast |
| **Pandoc → Beamer** | Write Markdown, compile to Beamer PDF. `pandoc -t beamer -o slides.pdf slides.md` |
| **Marp** | Markdown → slides (HTML/PDF). Fast for simple decks |
| **Slidev** | Vue-powered Markdown slides. Popular in tech talks |
| **Quarto** | R/Python/Julia → Beamer. Great for data-heavy presentations with live code output |
| **reveal.js + MathJax** | Web-based with LaTeX math support |

---

## 11. New & Notable (2025-2026)

- **BeamerQT** - new GUI for Beamer that simplifies creation (auto section layouts, aspect ratio config)
- **PDF/UA accessibility** - LuaLaTeX + Beamer accessibility option generates MathML tags automatically
- **Beamer Atelier** - design studio dedicated to teaching-first Beamer themes
- **latexpresents** - media-friendly package with auto-sizing and faux fullscreen for images/videos
- **Quarto** - R/Python/Julia publishing system that outputs Beamer (great for data-heavy talks)

---

## Sources

- [Overleaf Beamer Guide](https://www.overleaf.com/learn/latex/Beamer)
- [Pascal Michaillat's Minimalist Template](https://pascalmichaillat.org/c/)
- [Ultimate Beamer Theme List](https://github.com/martinbjeldbak/ultimate-beamer-theme-list)
- [LaTeX Beamer Advanced - Calmops](https://calmops.com/latex/latex-beamer-presentations-advanced/)
- [Overleaf Presentation Gallery](https://www.overleaf.com/gallery/tagged/presentation)
- [Beamer Theme Gallery](https://deic.uab.cat/~iblanes/beamer_gallery/)
- [Beamer Atelier](https://beameratelier.com/)
- [LaTeX Cloud Studio Beamer Guide](https://resources.latex-cloud-studio.com/learn/latex/how-to/presentations)
- [Baeldung - Making Presentations with LaTeX](https://www.baeldung.com/cs/latex-presentations)
- [LaTeX Templates - Presentations](https://www.latextemplates.com/cat/presentations)
- [TikZ.net Gallery](https://tikz.net/)
- [Awesome LaTeX](https://project-awesome.org/egeerardyn/awesome-LaTeX)
- [latexpresents on GitHub](https://github.com/robotic-esp/latexpresents)
