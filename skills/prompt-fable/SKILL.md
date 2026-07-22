---
name: prompt-fable
description: "Drafts a copy-pasteable prompt for Claude Fable 5 without dispatching anything. Use when the user says /prompt-fable, write me a fable prompt, draft a prompt for fable, help me prompt fable 5, or wants to hand a prompt to Fable somewhere else (the web app, another session, a colleague). For actually running the task, use the fable skill instead."
argument-hint: [rough task description]
---

# Draft a Fable 5 prompt

Produce a prompt the user can copy and paste. Do not dispatch a subagent, do not start the work, do not offer to. The deliverable is text.

Rough task: $ARGUMENTS

## 1. Clarify first

The rough task is almost never enough. Use `AskUserQuestion` to close the gaps that would change what gets written — skip anything already answered in the rough task or earlier in the session. Ask in one batch, not serially.

The gaps that matter most, roughly in order of leverage:

- **Why, and who for.** What larger goal does this serve, and who consumes the output? This is the single highest-leverage thing in a Fable prompt and the thing users most often leave out.
- **Definition of done.** What does a correct result look like, concretely enough that a verifier could check it?
- **Autonomy.** Will they be watching, or is this an unattended run? Changes whether the autonomous-operation block goes in.
- **Context to hand over.** Repos, paths, commands, prior decisions, constraints. Fable starts cold and will re-derive anything not given.
- **Scope ceiling.** Is there work adjacent to the task it should explicitly not touch?

Offer concrete options rather than open questions where you can infer the plausible answers from the rough task. If the user answers "other" or declines, write the prompt with a clearly marked `[FILL IN]` placeholder rather than inventing a fact about their situation.

## 2. Assemble

Write the prompt in this order. Omit sections that do not apply — a short prompt that fits the task beats a long one padded to a template.

1. **Framing** — `I'm working on [larger task] for [who]. They need [what the output enables]. With that in mind: [request].`
2. **The task** — what to do, stated as a goal rather than a procedure.
3. **Definition of done** — the checkable version.
4. **Context** — paths, repos, constraints, decisions already made.
5. **Scope boundaries** — only when there is real risk of over-reach.
6. **Verification cadence** — for long-running work: `Establish a method for checking your own work at an interval of [X] as you build. Run this every [X], verifying against the specification with subagents.`
7. **Autonomy block** — for unattended runs only, from `references/prompting-fable-5.md`.

State goals and constraints; let Fable choose the method. Prompts tuned for earlier models are usually too prescriptive for Fable 5 and measurably degrade its output, so resist enumerating steps it can work out itself.

Never include instructions telling Fable to echo, transcribe, or explain its internal reasoning as response text — that trips the `reasoning_extraction` refusal category and falls back to Opus.

## 3. Output

Emit the prompt in a single fenced code block, so it copies clean. Nothing inside the block except the prompt itself — no commentary, no headers the user would have to strip.

After the block, at most two lines: anything left as `[FILL IN]`, and any judgement call worth flagging. Do not explain the prompt back to them.

## Reference

Full guide, including the verbatim behavioral snippets and the effort-level guidance: `../fable/references/prompting-fable-5.md`.

Note that the snippets about scope discipline, honest progress reporting, delegation, and report style belong in a system prompt, not a task prompt. They are already baked into the `fable` agent definition. Include them in a drafted prompt only when the user is pasting into a context that lacks them, such as the web app.
