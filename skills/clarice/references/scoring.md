# Scoring & Recommendation Rules

This document defines how Clarice scores mock interviews and generates the overall recommendation.

## Core Principles

- **Follow-ups do not create new scored questions.** They only affect the *primary* question's score.
- Scoring is **weighted**: some questions matter more than others depending on role + seniority.
- Certain misses are **critical fails**: one severe gap can override an otherwise good score.
- Prefer **applied understanding** over trivia. Reward clear thinking, trade-offs, and honest uncertainty.

---

## Per-Question Scoring (0–20)

Each *primary* question receives one score `score` in `[0..20]`, influenced by any follow-ups.

Score bands:
- **18–20**: Excellent — comprehensive, accurate, deep; strong structure and trade-offs where relevant
- **14–17**: Good — correct core answer, minor gaps
- **10–13**: Acceptable — basic understanding, notable gaps
- **6–9**: Weak — partial understanding, significant gaps
- **0–5**: Poor — incorrect, unable to answer, or fundamental confusion

### What "good" means (scoring dimensions)

Use these dimensions to justify the score (not necessarily shown to the candidate):
- **Correctness**: technically accurate, no major misconceptions
- **Depth**: can explain implementation details / second-order effects appropriate to level
- **Clarity & structure**: organized answer, not rambling; uses examples when useful
- **Judgment / trade-offs** (as relevant): recognizes constraints, alternatives, failure modes

### Honesty rule

- Admitting "I don't know" (and explaining how they would find out) is **better than bluffing**.
- Bluffing or confidently incorrect statements should reduce **Correctness** and may trigger a critical flag if foundational.

---

## Weighting

Each primary question also gets a `weight` in `[1..5]`:

- **5 — Must-know** for this role/level (core competency)
- **4 — Very important** (strong signal area)
- **3 — Important** (meaningful but not decisive alone)
- **2 — Nice-to-have**
- **1 — Peripheral** / stretch / bonus

### How to assign weights (guidelines)

1. **JD must-haves** → weight **4–5**
2. **Role-defining fundamentals for the level** → weight **5**
3. **Focus areas explicitly requested by user/context** → weight **4–5**
4. **Candidate "known gaps" they want to probe** → weight **3–5** depending on importance
5. Edge cases / niche tech unrelated to JD → weight **1–2**

> Default rule: If uncertain, use `weight=3`.

---

## Critical Flags & Fast-Fail Rules

Some questions are *critical* for a given role/level.

Each question may include:
- `critical: true|false`
- `critical_miss: true|false` (set true only for severe failures)

### When a question is "critical"

Mark `critical=true` when it tests a foundational concept that a candidate at this level **must** understand to succeed in the real interview.

Examples:
- Senior Java: OOP basics (class/object/interface), exceptions, concurrency basics, JVM basics
- Mid/Senior Backend: API design fundamentals, debugging methodology, data modeling
- SRE/DevOps: Linux/networking fundamentals, incident reasoning, observability basics

### Critical miss definition

Set `critical_miss=true` if the candidate:
- cannot explain a foundational concept at all, **or**
- demonstrates a fundamental misconception that would cause repeated failure on the job/interview, **or**
- provides confidently wrong answers about a foundational concept after probing

Example:
- "Senior Java developer can't explain what a class is" → `critical=true`, `weight=5`, `critical_miss=true`

### Fast-fail recommendation cap

If **any** of these triggers occur, the overall recommendation is forced to **NOT READY** regardless of overall percentage:

- Any question with `critical_miss=true`
- Any question where `critical=true` and `score < 10`

Optional stricter rule (enable if desired):
- If **2+** critical questions score **< 14**, cap recommendation at **NEEDS TARGETED PRACTICE** (even if overall % is high)

---

## Overall Score Calculation

Let each question have:
- `score_i` in `[0..20]`
- `weight_i` in `[1..5]`

Compute:

**Weighted Score (0-20)**
```
weighted_score = Σ(score_i * weight_i) / Σ(weight_i)
```

Notes:
- Follow-ups do not add to question count.
- If a question was asked but unscored (rare), exclude it from Σ entirely.

---

## Overall Recommendation Labels

Use these default thresholds **unless overridden by fast-fail rules**:

- **READY**: `weighted_score >= 14`
- **NEEDS TARGETED PRACTICE**: `10 <= weighted_score < 14`
- **NOT READY**: `weighted_score < 10`

If fast-fail triggers occur, recommendation becomes **NOT READY** regardless of `weighted_score`.

---

## Interviewer Operating Rules (for consistency)

- Score internally only; do **not** reveal scores during the mock.
- Ask **max 2 follow-ups** per primary question.
- If still unclear after follow-ups: score accordingly, note gap, move on.
- Favor applied reasoning over rote memorization; do not penalize for lack of trivia if reasoning is strong.

---

## Data Shape (for report generation)

For each primary question, store:
```yaml
- q_id: 1
  question: "..."
  type: "technical|behavioral|system_design|challenge"
  weight: 1-5
  critical: true|false
  score: 0-20
  notes:
    strengths: ["..."]
    gaps: ["..."]
    evidence: ["Direct quote or paraphrase of what they said"]
    followups_asked: ["..."]
  flags:
    critical_miss: true|false
    bluffing: true|false
```

---

## Example: Senior Java "class" question

```yaml
- q_id: 2
  question: "In Java, what is a class? Explain it like you would to a junior dev."
  type: "technical"
  weight: 5
  critical: true
  score: 4
  flags:
    critical_miss: true
```

Result:
- Fast-fail triggers → **NOT READY**, regardless of other scores.
