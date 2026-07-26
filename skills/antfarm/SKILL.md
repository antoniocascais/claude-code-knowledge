---
name: antfarm
description: User-invoked codebase recon via an ant-colony pattern. The moderator carves a large or unfamiliar codebase into disjoint territories, fans out cheap Haiku scout subagents that explore in parallel and dump full findings to /tmp scratchpads (returning only terse pointers), then one Sonnet verifier cross-checks every claim against the repo before reporting. Use to map an unfamiliar codebase or locate where something lives without bloating the main context.
argument-hint: [query or area to explore]
disable-model-invocation: true
---

# Antfarm

Recon a large/unfamiliar codebase by **fanning out cheap scout ants in parallel, then verifying with one stronger model.** You are the **moderator** (main loop): you scope the query, partition the tree, dispatch scouts, run the verifier, and synthesize. The scouts and verifier are real subagents.

The point is **context economy + coverage**: scouts write verbose findings to scratchpad files in `/tmp` and return only short pointers, so exploring a huge tree never floods your context. Disjoint territories guarantee coverage without redundant reading. The verifier is the guardrail against cheap-model hallucination.

## What this is for (scope)

Use when the codebase is **too big to read into context** and you need either (a) a **map** — structure, entry points, how subsystems connect — or (b) a **needle** — where X is implemented, where a behavior lives, which files touch Y. For small trees you can read directly, skip this; the orchestration overhead isn't worth it. User-invoked only; never auto-trigger.

## Inputs

Query is `$ARGUMENTS` if provided, else the recon goal under discussion. Infer the **mode** from the query (state which you picked):
- **Needle-hunt** — "where is X / what touches Y / find the code that does Z." Scouts hunt their territory for matches; verifier confirms the hit(s) and rules out false positives.
- **Survey** — "map this repo / how does subsystem A work / what are the entry points." Scouts characterize their territory; verifier consolidates into a coherent map.

If the query is ambiguous about which, ask one clarifying question before dispatching.

## Agents

Reuse the two model-pinned specialist defs (full model IDs, bypass the `haiku` alias remap):
- **Scout ant** → `subagent_type: council-fast` (Haiku 4.5) — cheap, parallel.
- **Verifier** → `subagent_type: council-deep` (Sonnet 5) — exactly **one**, after the barrier.

If a spawn fails with "agent type not found," the defs in `~/.claude/agents/` aren't loaded — tell the user to reload agents rather than silently falling back to a default model.

## Scratchpad convention

Pick a short `<slug>` from the query (kebab-case, no spaces). All run artifacts live under `/tmp/antfarm/<slug>/`:
- Scouts write `/tmp/antfarm/<slug>/scout-NN.md` (NN = territory number).
- Verifier writes `/tmp/antfarm/<slug>/report.md`.

Create the directory before dispatching. If a slug collides with an existing run, suffix it so you don't read stale findings.

## Protocol

### 1. Recon + partition (moderator, once)
Cheap structural scan only — do **not** read file contents yet. Use `git ls-files`, `glob`, or a shallow `tree` to see the top 1–2 levels and identify subsystems (dirs, packages, services, layers). Carve the tree into **disjoint territories** — every relevant path belongs to exactly one scout, no overlap. **Scout count: up to 3, hard cap. Use fewer when the relevant surface is small** (1–2 territories is fine); don't spawn vanity ants for empty territory. If there are more than 3 subsystems, group them into 3 balanced territories rather than adding scouts. State your territories + scout count + one-line rationale before dispatching.

### 2. Fan-out scouts (single message, barrier)
Spawn all scouts as **named** (`name:` = territory, e.g. `scout-api`) `council-fast` subagents in **one message** so they run in parallel. Give each:
- Its **territory** (explicit path set / globs) — and that it must stay within it.
- The **query + mode**.
- Its **scratchpad path** and the output contract below.

Scout charge / output contract:
- **Write FULL findings to your scratchpad** — files, symbols, line refs, how pieces connect, everything matching the query. Verbose is fine here; it's a file, not the moderator's context.
- **Return to the moderator only**: scratchpad path · a 3–5 line summary · confidence (low/med/high) · explicit **uncertainty flags** (guesses, unread files, things that look relevant but sit outside your territory). Do not paste full findings into the return.

### 3. Barrier
Proceed **only after every scout has returned with content.** A scout counts only if its result came back non-empty. If one is missing, re-dispatch it **once**; if it still drops, proceed and treat its territory as **uncovered** — report the gap. **Never fabricate a dropped scout's findings**; a hallucinated territory summary is the worst possible output.

### 4. Verify (one Sonnet pass)
Spawn a **single** `council-deep` verifier. Give it: the query + mode, the list of scratchpad paths, and the territory map. Verifier charge:
- **Read every scout scratchpad**, then **spot-check claims against the actual repo** — open the cited files/lines, confirm paths and symbols exist and say what the scout claims. Catch hallucinations, overreach, and gaps.
- **Needle mode**: confirm the located hit(s), rule out false positives, note any territory where the needle could hide but coverage was thin.
- **Survey mode**: consolidate scouts into one coherent map; reconcile contradictions between territories.
- **Write the consolidated, verified result to `report.md`.** Return: verdict (confirmed / corrections / gaps) · the synthesized answer · confidence · a **coverage assessment** (territories with weak or no coverage).

Do **not** spawn a verifier per scout — it's one pass over the consolidated findings.

## Report (moderator)

Deliver, in order:
1. **Answer** — the verified map or located needle, synthesized from `report.md`.
2. **Corrections** — anything the verifier overturned in the scouts' claims (kept visible, not memory-holed).
3. **Coverage** — territories explored, scout count, and any **uncovered/thin** areas (dropped scouts, low-confidence zones) so the user knows the blind spots.
4. **Artifacts** — the `/tmp/antfarm/<slug>/` path, for follow-up.

## Rules
- **Cost hygiene**: scouts are Haiku (cheap); one Sonnet verifier. Scale scouts to real subsystems, not a target number. Don't use Monitor — background-agent completions notify you automatically. Don't load extra tools mid-run.
- **Disjoint territories**: overlap wastes the parallelism. If subsystems are entangled, split by responsibility, not by overlapping paths.
- **The verifier is a skeptic, not a rubber stamp** — its job is to break the scouts' claims, not bless them. Cheap-model findings are unverified until it confirms them.
- **Context discipline**: scouts' verbose output stays in scratchpads. If you find yourself with full file dumps in your context, the pattern failed — re-dispatch with a tighter return contract.

## Maintenance — pinned models
The seats pin **full model IDs** (in `~/.claude/agents/council-{deep,fast}.md`, shared with the `council` skill) to bypass the user's `ANTHROPIC_DEFAULT_HAIKU_MODEL` alias remap. Full IDs do **not** auto-upgrade and will break/degrade when the model is retired.

- `council-fast` (scout) → `claude-haiku-4-5-20251001`
- `council-deep` (verifier) → `claude-sonnet-5`
- Pinned: 2026-07. Re-check when a new Sonnet/Haiku ships or these EOL — bump the IDs in those two defs.
