#!/usr/bin/env python3
"""Interactive terminal quiz runner.

Usage: quiz.py <questions.json> [results.json]

Questions JSON format:
[
  {
    "question": "What is ...?",
    "options": [
      {"label": "Option A", "correct": false, "description": "Why this is wrong/right"},
      {"label": "Option B", "correct": true, "description": "Explanation"},
      ...
    ]
  }
]

Options are shuffled automatically. Results are written to the results file
(default: /tmp/quiz_results.json) for Claude to read back.
"""
import json
import os
import re
import sys
import time
import random

GREEN = "\033[32m"
RED = "\033[31m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"


def run_quiz(questions):
    results = []
    total = len(questions)

    print(f"\n{BOLD}{'='*50}{RESET}")
    print(f"{BOLD}  QUIZ — {total} question{'s' if total != 1 else ''}{RESET}")
    print(f"{BOLD}{'='*50}{RESET}\n")

    for i, q in enumerate(questions, 1):
        print(f"{BOLD}[{i}/{total}] {q['question']}{RESET}\n")

        options = q["options"]
        for j, opt in enumerate(options, 1):
            print(f"  {j}. {opt['label']}")

        print()
        start = time.time()

        while True:
            try:
                raw = input("  Your answer (number): ").strip()
                choice = int(raw)
                if 1 <= choice <= len(options):
                    break
                print(f"  Pick 1-{len(options)}")
            except ValueError:
                print(f"  Pick 1-{len(options)}")
            except (EOFError, KeyboardInterrupt):
                print("\n  Quiz cancelled.")
                sys.exit(1)

        elapsed = round(time.time() - start, 1)
        selected = options[choice - 1]
        correct = selected.get("correct", False)
        correct_opt = next(o for o in options if o.get("correct"))

        results.append({
            "question": q["question"],
            "selected": selected["label"],
            "correct_answer": correct_opt["label"],
            "is_correct": correct,
            "time_seconds": elapsed,
            "explanation": correct_opt["description"],
        })

        if correct:
            print(f"  {GREEN}✓ Correct{RESET} {DIM}({elapsed}s){RESET}\n")
        else:
            print(f"  {RED}✗ Wrong{RESET} — answer was: {correct_opt['label']} {DIM}({elapsed}s){RESET}\n")

    score = sum(1 for r in results if r["is_correct"])
    avg_time = round(sum(r["time_seconds"] for r in results) / total, 1)

    print(f"{BOLD}{'='*50}{RESET}")
    print(f"{BOLD}  Score: {score}/{total}  |  Avg time: {avg_time}s{RESET}")
    print(f"{BOLD}{'='*50}{RESET}\n")

    return {"score": score, "total": total, "avg_time": avg_time, "results": results}


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <questions.json> [results.json]")
        sys.exit(1)

    questions_path = sys.argv[1]
    if len(sys.argv) > 2:
        results_path = sys.argv[2]
    else:
        # Derive results path: quiz_questions_1738842000.json → quiz_results_1738842000.json
        results_path = re.sub(r'quiz_questions', 'quiz_results', questions_path)
        if results_path == questions_path:
            # Fallback if filename doesn't match pattern
            base = os.path.splitext(questions_path)[0]
            results_path = f"{base}_results.json"

    with open(questions_path) as f:
        questions = json.load(f)

    for q in questions:
        random.shuffle(q["options"])

    results = run_quiz(questions)

    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)

    print(f"Results saved to {results_path}")


if __name__ == "__main__":
    main()
