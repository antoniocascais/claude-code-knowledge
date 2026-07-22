---
name: fable
description: "Dispatches a task to a Claude Fable 5 subagent with a prompt written the way Fable 5 wants to be prompted. Use when the user says /fable, fable, fable 5, send this to fable, hand this off to fable, or when a task sits at the top of the difficulty range: multi-hour or multi-day implementations, deep debugging, whole-repo review or bug hunts, dense technical screenshots, or ambiguous multithreaded requests where first-shot correctness matters."
argument-hint: [task description]
---

# Dispatch to Fable 5

Turn the user's ask into a Fable-shaped task prompt and hand it to the `fable` subagent. Behavioral tuning (scope discipline, honest progress reporting, no early stopping, delegation, report style) already lives in the agent definition. Write the task, not the personality.

Task: $ARGUMENTS

## 1. Check the fit

Fable 5 is for the hard end of the range. Route elsewhere when:

- The task is a routine edit or a quick lookup — just do it in-session, or use a normal subagent. Say so rather than dispatching.
- The task touches offensive cybersecurity (exploits, malware, attack tooling) or biology and life sciences (lab methods, molecular mechanisms). Fable runs classifiers on those domains and returns `stop_reason: "refusal"` even for benign work. Handle it in-session or with an Opus subagent.

If the ask is vague, ask one or two clarifying questions before dispatching. Fable navigates ambiguity well, but a run this expensive should not start pointed at the wrong target.

## 2. Write the prompt

Include, in this order:

**The why, not only the what.** Highest-leverage addition. Context lets Fable connect the task to relevant information instead of inferring intent.

```
I'm working on [larger task] for [who it's for]. They need [what the output enables].
With that in mind: [request].
```

**The definition of done.** Concrete enough that a verifier subagent could check it against a specification.

**Starting context.** Paths, repos, commands to run, constraints, decisions already made — everything established in this session that Fable would otherwise re-derive from scratch.

**Verification cadence**, for anything long-running:

```
Establish a method for checking your own work at an interval of [X] as you build.
Run this every [X], verifying against the specification with subagents.
```

**A notes path**, when the work spans sessions or should accumulate lessons. Fable performs notably better with somewhere to record them.

Then dispatch:

```
Agent(subagent_type: "fable", description: "<3-5 words>", prompt: "<the above>")
```

Subagents run in the background, so the user can keep working while it runs.

## 3. Autonomous runs

When the user will not be watching (overnight, background, scheduled), append:

```
You are operating autonomously. The user is not watching in real time and cannot answer
questions mid-task, so asking "Want me to…?" or "Shall I…?" will block the work. For
reversible actions that follow from the original request, proceed without asking.
```

## 4. Relay the result

The agent's report is not shown to the user. Lead with the outcome, then whatever it needs from them. Do not pad it with commentary.

## Caveats

- Fable runs long: many minutes per turn, hours for autonomous work. Tell the user up front so a silent gap does not read as a hang.
- Never instruct Fable to echo, transcribe, or explain its internal reasoning as response text. That trips the `reasoning_extraction` refusal category and falls back to Opus.
- Resist over-specifying. Prompts and skills tuned for earlier models are usually too prescriptive for Fable 5 and degrade its output. State the goal and the constraints; let it pick the method.

Full prompting guide: `references/prompting-fable-5.md`.
