# Content shape → visual format

How to pick a format per content chunk, plus copy-paste snippets. All snippets use the classes defined in `assets/template.html`. Build the page by composing these.

## Table of contents
- [Decision guide](#decision-guide)
- [Diagrams (the priority)](#diagrams-the-priority)
- [Callouts](#callouts)
- [Cards](#cards)
- [Comparison tables](#comparison-tables)
- [Stepper](#stepper)
- [Tree / mind-map](#tree--mind-map)
- [Accordion vs tabs (density)](#accordion-vs-tabs-density)
- [Quality bar](#quality-bar)

## Decision guide

Read the chunk and ask "what *kind* of thing is this?":

- **Things connected by flow/dependency** (request path, data pipeline, service topology) → **diagram**. This is the highest-value format for the DevOps/SRE audience — invest effort here.
- **One thing happening after another** (runbook, deploy sequence, CI stages) → **stepper**.
- **Several alternatives being weighed** → **comparison table** + recommendation callout. Highlight the winning row with `.pick`.
- **A set of peer concepts/components** → **card grid**.
- **A single sharp point** (gotcha, takeaway, caveat) → **callout** with the right semantic.
- **Containment / hierarchy / taxonomy** → **tree**.
- **Supporting depth most readers skip** → **accordion**.
- **Mutually-exclusive parallel views of the same thing** (e.g. "YAML vs CLI", "AWS vs GCP") → **tabs**.

Most pages mix 3–6 of these. Lead with summary + key-insight callout, then the main diagram, then detail.

## Diagrams (the priority)

Two build methods. Use SVG when geometry matters (branching, fan-out, non-linear); use CSS flex boxes for simple linear chains.

### CSS box-and-arrow (linear)
```html
<div class="flow">
  <div class="node">Client</div>
  <span class="arrow">→</span>
  <div class="node accent">LB<span class="sub">L7</span></div>
  <span class="arrow">→</span>
  <div class="node">App</div>
  <span class="arrow down">↓</span>           <!-- wrap to next row -->
  <div class="node">DB<span class="sub">primary</span></div>
</div>
```

### Inline SVG (branching / topology / fan-out)
Use a `viewBox`, currentColor-friendly strokes, and the CSS vars by hardcoding hex (SVG can't read CSS vars reliably across contexts — use the palette values directly: ink `#1c2128`, accent `#2563eb`, border `#cdd2d9`, faint `#6b7280`).

```html
<svg viewBox="0 0 640 240" width="100%" font-family="sans-serif" font-size="13">
  <!-- box helper pattern: rect + centered text -->
  <rect x="20" y="100" width="120" height="44" rx="8" fill="#fff" stroke="#cdd2d9" stroke-width="1.5"/>
  <text x="80" y="127" text-anchor="middle" fill="#1c2128" font-weight="600">Ingress</text>

  <rect x="260" y="40" width="120" height="44" rx="8" fill="#eff4ff" stroke="#2563eb" stroke-width="1.5"/>
  <text x="320" y="67" text-anchor="middle" fill="#2563eb" font-weight="600">svc-a</text>

  <rect x="260" y="160" width="120" height="44" rx="8" fill="#fff" stroke="#cdd2d9" stroke-width="1.5"/>
  <text x="320" y="187" text-anchor="middle" fill="#1c2128" font-weight="600">svc-b</text>

  <!-- arrows with a marker -->
  <defs>
    <marker id="a" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto">
      <path d="M0,0 L7,3 L0,6 Z" fill="#6b7280"/>
    </marker>
  </defs>
  <path d="M140,118 C200,118 200,62 258,62"  stroke="#6b7280" fill="none" marker-end="url(#a)"/>
  <path d="M140,126 C200,126 200,182 258,182" stroke="#6b7280" fill="none" marker-end="url(#a)"/>
</svg>
```

Guidance:
- Label edges when the relation isn't obvious (protocol, port, sync/async) with a small `<text>`.
- Keep ≤ ~9 nodes per diagram; split larger topologies into layered diagrams.
- Mark the focal node with the accent style so the eye knows where to start.

## Callouts

Four semantics — pick by intent, don't mix meaning:
- `info` (blue) — neutral note, clarification.
- `tip` (green) — recommendation, best practice, the "do this".
- `warn` (amber) — gotcha, footgun, caveat.
- `insight` (purple) — the big takeaway. Use sparingly (1–2 per page) so it stays loud.
- `danger` (red) — data-loss / irreversible / security.

```html
<div class="callout tip"><span class="label">Recommendation</span><p>…</p></div>
<div class="callout warn"><span class="label">Gotcha</span><p>…</p></div>
```

## Cards

For a set of peers (components, options, concepts). Optional leading emoji as a lightweight icon.
```html
<div class="grid">
  <div class="card"><span class="icon">🔐</span><h3>cert-manager</h3><p>Issues + rotates TLS certs.</p></div>
  <div class="card"><span class="icon">🌐</span><h3>external-dns</h3><p>Syncs DNS from Ingress.</p></div>
</div>
```

## Comparison tables

The workhorse for tradeoffs. Add a `When` column for "reach for this if…", and mark the default with the `.pick` row class + a ⭐.
```html
<table>
  <thead><tr><th>Option</th><th>Pros</th><th>Cons</th><th>When</th></tr></thead>
  <tbody>
    <tr class="pick"><td><b>NGINX Ingress</b> ⭐</td><td><span class="yes">✓</span> Ubiquitous</td><td><span class="no">✗</span> Reload churn</td><td>Default</td></tr>
    <tr><td>Gateway API</td><td><span class="yes">✓</span> Future-proof</td><td><span class="no">✗</span> Maturity</td><td>Greenfield</td></tr>
  </tbody>
</table>
<div class="callout tip"><span class="label">Recommendation</span><p>Pick + one-line why.</p></div>
```

## Stepper

Ordered process / runbook. Keep each step's body to 1–2 lines; push detail into a nested accordion if needed.
```html
<ol class="steps">
  <li><b>Drain node</b><p><code>kubectl drain …</code></p></li>
  <li><b>Patch + reboot</b><p>Apply, wait for Ready.</p></li>
  <li><b>Uncordon</b><p>Return to scheduling.</p></li>
</ol>
```

## Tree / mind-map

Hierarchy / taxonomy / "what contains what".
```html
<ul class="tree">
  <li><span class="leaf">cluster</span>
    <ul>
      <li><span class="leaf">namespace: prod</span>
        <ul><li><span class="leaf">deploy/api</span></li><li><span class="leaf">deploy/worker</span></li></ul>
      </li>
    </ul>
  </li>
</ul>
```

## Accordion vs tabs (density)

This is the adaptive-density decision:
- **Accordion** (`<details>`): supplementary depth a reader *may* skip. Default closed. Good for gotchas, derivations, full configs, "why" deep-dives.
- **Tabs**: 2–5 *mutually exclusive equals* viewing the same slot — the reader wants one at a time, none is "extra" (YAML vs CLI, per-cloud variants, before/after).
- **Neither** (static): summaries, the main diagram, the key comparison table — anything a reader should hit without a click.

Rule of thumb: if hiding it would make the reader miss something important → keep static. If showing all of it at once creates a wall → accordion/tabs.

## Quality bar

Before writing the file, sanity-check:
- Page opens standalone — no `http(s)://`, no `<link>`/`<script src>` to anything external, no web-font fetch.
- Summary + key insight are above the fold; structure graspable in ~5 seconds.
- Every accent color carries meaning; nothing decorative-only.
- At least one real diagram if the content is architectural.
- TOC present for pages with 4+ sections; omit for short ones.
- Filename is descriptive kebab-case in `/tmp/`.
