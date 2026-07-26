---
name: council
description: User-invoked breadth check — convenes 3 specialist subagent personas to pressure-test a plan/decision/diff from angles you might have missed, surfacing framed positions + a dissent log. Intended to run AFTER the user has already reasoned through the problem, as a final "did we miss anything" sweep.
argument-hint: [topic] [--debate]
disable-model-invocation: true
---

# Council

Convene 3 specialist personas (real subagents) to pressure-test a topic. They are **one base model sampled in 3 directions**, not 3 independent minds — so the product is a **menu of framed positions + a dissent log the user adjudicates**, NOT an authoritative "consensus." You are the **moderator**: select the council, run it, synthesize. Selecting personas + framing prompts + writing the synthesis is itself a quiet editorial vote — so always show the raw persona outputs, not just your synthesis. The user is the decider.

## What this is for (scope)
**Breadth, not depth.** Use this to *surface angles* — to catch the security/ops/UX/cost lens you skipped — NOT to resolve a hard problem. For depth, the main model (the moderator) reasoning directly beats shallow parallel sampling from cheaper persona models. The intended workflow: the user brainstorms the hard thinking directly with the main model, *then* invokes `/council` as a cheap final sweep for missed considerations. This is user-invoked only; never auto-trigger it.

## Inputs

Topic is `$ARGUMENTS` if provided, else the plan/code/decision under discussion. If ambiguous, ask one clarifying question before convening.

**Mode** (cost control — this is the whole point):
- **Default = single blind fan-out.** 3 parallel independent takes → moderator synthesis. One round. Cheap (~3 subagent calls). This captures ~85% of the value: blind parallelism defeats anchoring, persona-conditioning pushes off-centroid, the dissent log surfaces the unflattering branches a solo answer averages away.
- **`--debate` = add rebuttal rounds** (max 2 extra). Only when the user explicitly asks, or the fan-out shows a sharp, decision-relevant split worth resolving. Debate rounds cost the most and add the least — relay re-injects every position into every agent, so cost is super-linear. Earn them.

## Persona roster

A persona = a charge in the spawn prompt. The **model** comes from which agent type you spawn it as:
- **`council-deep`** → Sonnet 5 — the harder reasoning seats.
- **`council-fast`** → Haiku 4.5 — standard seats (default).

Both pin a full model ID (bypassing any `haiku` alias remap) and inherit full tools, so personas can read the repo to ground feedback.

Pick the **3 most relevant**. **At most 1 `council-deep` seat** (so: 3 fast, or 2 fast + 1 deep). Deep is the cost driver — reserve it for genuinely hard topics.

**Deep-eligible** (spawn as `council-deep`, pick ≤1):
- **The Architect** — systems thinking, long-term consequences, coupling, what this forecloses.
- **The Skeptic** — devil's advocate; attacks assumptions, "why will this fail".

**Standard** (spawn as `council-fast`):
- **The Pragmatist** — ship it, YAGNI, scope discipline.
- **The Operator** — SRE/on-call: failure modes, observability, blast radius, rollback.
- **The Security Hawk** — threat model, authz, data exposure, secrets, supply chain.
- **The Reviewer** — correctness, edge cases, tests, maintainability.
- **The Cost Cutter** — infra/$/token cost, complexity budget, overengineering.
- **The User Advocate** — DX/UX, API ergonomics, the actual user.

(Any persona *can* be promoted to `council-deep` if the topic makes it the load-bearing seat — but still ≤1 deep total.)

### Selection heuristics
- auth / data / external input → Security Hawk + Architect(deep) + Operator
- infra / deploy / reliability → Operator + Pragmatist + Architect(deep)
- "X or Y" decision → Skeptic(deep) + Pragmatist + (domain fit)
- code review → Reviewer + Skeptic + (domain fit)
- debugging → Skeptic(deep) + Operator + Reviewer (distinct hypotheses)
- greenfield → Architect(deep) + Pragmatist + User Advocate

State your 3 picks + their seat (deep/fast) + one-line why before spawning.

## Protocol

### Pre-stage context (review / debug topics)
Before spawning, if the topic involves a repo (code review, debugging), the moderator gathers the shared context **once** — run `git diff`, list relevant files, pull the key code — and injects it into all three prompts. This avoids 3 personas redundantly exploring the same thing. Personas still have full tools to go *beyond* your packet if their lens demands it (so your curation isn't a silent veto). For pure plan/decision/debate topics, just pass the plan text.

### Preflight (once, before spawning)
The persona seats depend on two agent defs in `~/.claude/agents/`: `council-deep.md` and `council-fast.md`. If a spawn fails with "agent type not found," they aren't loaded — tell the user to reload agents (or that the defs are missing on this machine, e.g. fresh clone) rather than silently falling back to a default model.

### Fan-out (always)
Spawn all 3 as **named** subagents (`name:` = persona) via the **agent type** for their seat — `subagent_type: council-deep` (Sonnet) or `council-fast` (Haiku) — in a **single message** (parallel, blind — none sees the others). Give each: shared context + persona charge + the output contract. **Seat one as an unconditional contrarian** — its charge includes "argue the strongest case *against* the obvious answer." This is mandatory, not moderator-discretion (a moderator who skips dissent because agreement "felt fine" is the failure mode).

Output contract per persona:
- **Position** — recommendation, 1–2 sentences.
- **Reasoning** — top 2–3 points, terse.
- **Risks/objections** — what worries them most.
- **Confidence** — low / med / high.

### Liveness — never backfill a dropped voice
`SendMessage`/spawn is effectively fire-and-forget; you only know a voice returned if you got an **actual result with content**. A voice counts ONLY if its spawn/SendMessage result came back non-empty. If one is missing: re-send **once**, else proceed and **explicitly report "ran with 2/3 voices — <persona> dropped."** Never invent or pattern-complete a missing persona's take — a phantom 3rd voice fabricated from your own priors is the worst possible output.

### Debate rounds (`--debate` only, ≤2 extra)
Capture each `agentId` from the fan-out results. Resume via `SendMessage` to that `agentId` (resumes from transcript).
- **Cost discipline**: pass only the *other positions' deltas*, not full transcripts — the agent already has its own context. Don't re-paste what it can see.
- **Fidelity check**: a resume can rehydrate from a compacted transcript and silently lose context. Require each persona to **restate its own prior position in one line** before arguing the new round. Drift/generic restatement = corruption signal → flag it, don't trust that voice.
- Round charge: "Here are the others' positions. Rebut or concede on merit. Restate your position." Final round: "Converge if you honestly can; else state your hill."

## Verdict

Always deliver, in this order:
1. **Raw positions** — each persona's take, verbatim-ish (this is the real product; don't bury it under synthesis).
2. **Synthesis** — where they agree, where they split, the crux (the one fact/assumption that would change the answer). Frame as input, not oracle.
3. **Dissent log** — minority views kept visible; what each contrarian/conceding voice objected to and why it was folded in or overruled. Never memory-hole the minority.
4. **Your call** — if there's a live split: tradeoff table (options × what each optimizes/sacrifices) + **"Your call — which way?"**
5. **Council** — the 3 personas + tiers + mode (fan-out / debate) in one line.

## Rules
- You moderate, you don't vote. No 4th opinion injected during rounds.
- Don't oversell: it's a thinking aid (N=1 base model), not an independent panel. Frame output accordingly.
- Personas debate the **idea**, not each other. No sycophancy; concede only on merit.
- **Cost hygiene**: default to fan-out; don't use Monitor (background-agent completions notify you automatically); don't load extra tools mid-run; don't re-paste transcript content into relays. Use the `council-deep` (Sonnet) seat only when the topic earns it — `council-fast` (Haiku) is the default and is cheap.

## Maintenance — pinned models
The seats pin **full model IDs** (in `~/.claude/agents/council-{deep,fast}.md`) to bypass the user's `ANTHROPIC_DEFAULT_HAIKU_MODEL` alias remap. Full IDs do **not** auto-upgrade and will break/degrade when the model is retired.

- `council-deep` → `claude-sonnet-5`
- `council-fast` → `claude-haiku-4-5-20251001`
- Pinned: 2026-06. Re-check when a new Sonnet/Haiku ships or these EOL — bump the IDs in those two defs.
