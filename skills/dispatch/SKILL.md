---
name: dispatch
description: >-
  Serialize the current brainstorm/design discussion into a structured
  implementation spec and delegate the build to the cheaper "executor" subagent
  (Sonnet). Use when the user says to dispatch, delegate, hand off, or offload
  implementation to the executor after designing an approach together.
disable-model-invocation: true
argument-hint: "[optional: focus/constraints for this dispatch]"
---

You are the orchestrator. The design thinking happens in THIS thread; the
cheaper executor subagent does the mechanical implementation. Run inline — do
not fork. Follow these steps.

## 1. Confirm the design is ready
You should be arriving here after a design discussion. If the task is still
vague, do NOT dispatch yet — resolve the open questions with the user first.
A weak executor fails on under-specified specs, not on typing.

## 2. Write the spec to a file
The executor starts with ZERO of this conversation's context. The spec file is
its entire world. Write it to `.claude/dispatch/spec.md` (create the dir) if in
a repo, otherwise to the session scratchpad. Use this structure:

```
# <task title>

GOAL
<one or two sentences — the WHY, the outcome>

FILES TO TOUCH
<exact paths. If a path must be created, say so.>

INTERFACE CONTRACTS
<function/type signatures, expected inputs/outputs, data shapes. This is the
highest-leverage section — pin every seam the executor must not decide.>

STEPS
<mechanical steps if non-trivial; leave obvious HOW to the executor>

DO NOT TOUCH
<explicit non-goals and files/behavior to leave alone>

DEFINITION OF DONE
<the exact command(s) that must pass — build, test, lint, typecheck>
```

Leave the mechanical *how* to the executor; pin the decisions (interfaces,
files, done-criteria). Fold any `$ARGUMENTS` (focus/constraints) into the spec.

## 3. Spawn the executor
Call the Agent tool with `subagent_type: executor` and `name: executor-run`
(the name makes it resumable). Prompt:

```
Implement the spec at <spec path>. Read it and the named source files first.
Implement exactly what's specified. If anything is ambiguous or uncovered,
return a BLOCKED: question instead of guessing.
```

## 4. Handle the return
Read the executor's final message:

- **Starts with `BLOCKED:`** — it hit ambiguity (this is by design, not failure).
  Do NOT treat it as done. Surface the question to the user, get the answer,
  update the spec file, then **resume the same executor** via SendMessage
  (`to: executor-run`) with: "Answer: <answer>. The spec at <path> is updated.
  Resume from where you stopped." Resuming keeps its context and partial work.
  Repeat until it completes.

- **Reports implementation** — review what changed and the verification output.
  Relay a concise summary to the user. Do not commit unless the user asks.
  If verification failed, decide whether to re-spec or resume with guidance.

## Notes
- The executor cannot spawn subagents or hit the web (tools are restricted) and
  cannot show interactive prompts — the BLOCKED convention is its only channel
  back to you. Honor it.
- Keep the spec file around across rounds; it's the shared state.
