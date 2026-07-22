# Prompting Claude Fable 5

Condensed from Anthropic's official guide: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5

## Contents

- [Where Fable 5 is stronger](#where-fable-5-is-stronger)
- [Longer turns by default](#longer-turns-by-default)
- [Effort levels](#effort-levels)
- [Strong instruction following](#strong-instruction-following)
- [Ground progress claims during long runs](#ground-progress-claims-during-long-runs)
- [State the boundaries](#state-the-boundaries)
- [Parallel subagents](#parallel-subagents)
- [Memory system](#memory-system)
- [Early stopping](#early-stopping)
- [Context-budget concern](#context-budget-concern)
- [Give the reason, not only the request](#give-the-reason-not-only-the-request)
- [Readability when communicating with the user](#readability-when-communicating-with-the-user)
- [send_to_user tool](#send_to_user-tool)
- [Scaffolding changes](#scaffolding-changes)
- [Refusal domains](#refusal-domains)

## Where Fable 5 is stronger

Compared with Opus 4.8: long-horizon autonomy across multiday goal-directed runs; first-shot correctness on complex, well-specified problems; vision on dense technical images and screenshots; enterprise workflows (financial analysis, spreadsheets, slides, documents); code review and bug-finding recall including search across repository history; navigating ambiguous multithreaded requests; dispatching and sustaining parallel subagents.

Teams see the best outcomes applying it to their hardest unsolved problems. Testing it only on simpler workloads undersells its range.

## Longer turns by default

Individual requests on hard tasks run for many minutes at higher effort; autonomous runs extend for hours. Adjust client timeouts, streaming, and progress indicators before migrating. Prefer checking on runs asynchronously over blocking.

To keep it from overplanning when a task is ambiguous:

```
When you have enough information to act, act. Do not re-derive facts already established in the conversation, re-litigate a decision the user has already made, or narrate options you will not pursue in user-facing messages. If you are weighing a choice, give a recommendation, not an exhaustive survey. This does not apply to thinking blocks.
```

## Effort levels

Effort is the primary intelligence/latency/cost control. Default to `high`; `xhigh` for the most capability-sensitive workloads; `medium` or `low` for routine work. Low effort on Fable 5 often exceeds `xhigh` on prior models. Reduce effort if a task completes but takes longer than necessary, or for a more interactive working style.

At higher effort it can gather context and deliberate beyond what the task needs, though it also produces the best verification behavior and most rigorous output. To prevent unrequested tidying or refactoring:

```
Don't add features, refactor, or introduce abstractions beyond what the task requires. A bug fix doesn't need surrounding cleanup and a one-shot operation usually doesn't need a helper. Don't design for hypothetical future requirements: do the simplest thing that works well. Avoid premature abstraction and half-finished implementations. Don't add error handling, fallbacks, or validation for scenarios that cannot happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs). Don't use feature flags or backwards-compatibility shims when you can just change the code.
```

## Strong instruction following

Steer most behaviors with a brief instruction rather than enumerating each behavior by name. Un-steered, Fable 5 can elaborate beyond what the task needs: surveying options it will not pursue, explaining root causes at length, heavily-structured PR descriptions, comments narrating the next line. A short brevity instruction matches listing every pattern:

```
Lead with the outcome. Your first sentence after finishing should answer "what happened" or "what did you find": the thing the user would ask for if they said "just give me the TLDR." Supporting detail and reasoning come after. Being readable and being concise are different things, and readability matters more.

The way to keep output short is to be selective about what you include (drop details that don't change what the reader would do next), not to compress the writing into fragments, abbreviations, arrow chains like A → B → fails, or jargon.
```

Same for checkpoint behavior in long-running workflows:

```
Pause for the user only when the work genuinely requires them: a destructive or irreversible action, a real scope change, or input that only they can provide. If you hit one of these, ask and end the turn, rather than ending on a promise.
```

## Ground progress claims during long runs

In Anthropic's testing this nearly eliminated fabricated status reports even on tasks designed to elicit them:

```
Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly. Report outcomes faithfully: if tests fail, say so with the output; if a step was skipped, say that; when something is done and verified, state it plainly without hedging.
```

## State the boundaries

Fable 5 can occasionally take unrequested actions (drafting an email when none was asked for, creating defensive git-branch backups):

```
When the user is describing a problem, asking a question, or thinking out loud rather than requesting a change, the deliverable is your assessment. Report your findings and stop. Don't apply a fix until they ask for one. Before running a command that changes system state (restarts, deletes, config edits), check that the evidence actually supports that specific action. A signal that pattern-matches to a known failure may have a different cause.
```

## Parallel subagents

Fable 5 dispatches parallel subagents more readily than prior models. Use subagents frequently, give explicit guidance on when delegation is appropriate, and prefer asynchronous orchestrator/subagent communication over blocking. Long-lived subagents that keep context across subtasks save time and cost through cache reads and avoid bottlenecking on the slowest subagent.

```
Delegate independent subtasks to subagents and keep working while they run. Intervene if a subagent goes off track or is missing relevant context.
```

## Memory system

Fable 5 performs particularly well when it can record lessons from previous runs and reference them. A Markdown file is enough:

```
Store one lesson per file with a one-line summary at the top. Record corrections and confirmed approaches alike, including why they mattered. Don't save what the repo or chat history already records; update an existing note rather than creating a duplicate; delete notes that turn out to be wrong.
```

To bootstrap from existing history:

```
Reflect on the previous sessions we've had together. Use subagents to identify core themes and lessons, and store them in [X]. Make sure you know to reference [X] for future use.
```

## Early stopping

Deep into a long session, Fable 5 can occasionally end a turn with a text-only statement of intent ("I'll now run X") without the corresponding tool call, or pause to ask permission when it already has enough to proceed. A "continue" or "go ahead and do it end to end" suffices. For autonomous pipelines:

```
You are operating autonomously. The user is not watching in real time and cannot answer questions mid-task, so asking "Want me to…?" or "Shall I…?" will block the work. For reversible actions that follow from the original request, proceed without asking. Offering follow-ups after the task is done is fine; asking permission after already discussing with the user before doing the work is not. Before ending your turn, check your last paragraph. If it is a plan, an analysis, a question, a list of next steps, or a promise about work you have not done ("I'll…", "let me know when…"), do that work now with tool calls. End your turn only when the task is complete or you are blocked on input only the user can provide.
```

## Context-budget concern

In very long sessions Fable 5 can suggest a new session, offer to summarize and hand off, or trim its own work — most often when the harness shows a remaining-token countdown. Avoid surfacing explicit context-budget counts. If the harness must show them:

```
You have ample context remaining. Do not stop, summarize, or suggest a new session on account of context limits. Continue the work.
```

## Give the reason, not only the request

Context lets Fable connect the task to relevant information rather than inferring intent on its own. Especially valuable for long-running agents drawing on multiple workstreams:

```
I'm working on [the larger task] for [who it's for]. They need [what the output enables]. With that in mind: [request].
```

## Readability when communicating with the user

In extended agentic conversations, Fable 5 can produce dense arrow-chain shorthand, deep implementation detail, references to thinking the user never saw, or overly technical phrasing:

```
Terse shorthand is fine between tool calls (that's you thinking out loud, and brevity there is good). Your final summary is different: it's for a reader who didn't see any of that.

If you've been working for a while without the user watching (overnight, across many tool calls, since they last spoke), your final message is their first look at any of it. Write it as a re-grounding, not a continuation of your working thread: the outcome first, then the one or two things you need from them, each explained as if new. The vocabulary you built up while working is yours, not theirs; leave it behind unless you re-introduce it.

When you write the summary at the end, drop the working shorthand. Write complete sentences. Spell out terms. Don't use arrow chains, hyphen-stacked compounds, or labels you made up earlier. When you mention files, commits, flags, or other identifiers, give each one its own plain-language clause. Open with the outcome: one sentence on what happened or what you found. Then the supporting detail. If you have to choose between short and clear, choose clear.
```

## send_to_user tool

For long asynchronous agents, a client-side tool that surfaces a message the user must see exactly as written, without ending the turn. Tool inputs are never summarized, so content arrives intact. Render the input in your UI and return a simple acknowledgement.

```json
{
  "name": "send_to_user",
  "description": "Display a message directly to the user. Use this for progress updates, partial results, or content the user must see exactly as written before the task finishes.",
  "input_schema": {
    "type": "object",
    "properties": {
      "message": {
        "type": "string",
        "description": "The content to display to the user."
      }
    },
    "required": ["message"]
  }
}
```

Defining the tool is not sufficient — without a system-prompt instruction Fable 5 rarely calls it:

```
Between tool calls, when you have content the user must read verbatim (a partial deliverable, a direct answer to their question), call the send_to_user tool with that content. Use send_to_user only for user-facing content, not for narration or reasoning.
```

Do not route narration or internal reasoning through it.

## Scaffolding changes

- **Start at the top of your difficulty range.** Pick a task harder than what you would assign prior models, and have Fable scope it, ask clarifying questions, and execute.
- **Make self-verification explicit.** Separate, fresh-context verifier subagents outperform self-critique. `Establish a method for checking your own work at an interval of [X] as you build. Run this every [X interval], verifying your work with subagents against the specification.`
- **Refactor existing prompts and skills.** Skills developed for prior models are often too prescriptive and degrade output quality. Remove older instructions where default performance is better. Fable also updates skills on the fly based on what it learns from the task.
- **Never instruct it to reproduce its reasoning in the response.** Prompts telling the model to echo, transcribe, or explain internal reasoning as response text trigger the `reasoning_extraction` refusal category and cause elevated fallbacks to Opus 4.8. Audit existing skills and system prompts for show-your-thinking instructions. For reasoning visibility, read the structured `thinking` blocks from adaptive thinking instead.

## Refusal domains

Fable 5 runs safety classifiers targeting offensive cybersecurity (exploits, malware, attack tooling), biology and life sciences (lab methods, molecular mechanisms), and extraction of the model's summarized thinking. Benign work in those areas may also trigger them. Configure server-side or client-side fallback to Opus 4.8 to re-route declined requests.

API notes: adaptive thinking only, summarized-only thinking output, no extended thinking budgets, `refusal` stop reason.
