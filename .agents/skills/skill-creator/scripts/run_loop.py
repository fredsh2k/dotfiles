#!/usr/bin/env python3.12
"""Run the eval→improve→re-eval optimization loop using the Copilot SDK.

Orchestrates multiple rounds of:
1. Evaluate current description against the eval set
2. Use Copilot to suggest an improved description
3. Re-evaluate the improved description
4. Keep the best-performing description

Requires: pip install github-copilot-sdk
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from scripts.run_eval import run_eval
from scripts.improve_description import improve_description
from scripts.utils import parse_skill_md


def run_loop(
    skill_path: Path,
    eval_set_path: Path,
    max_rounds: int = 5,
    target_score: float = 1.0,
    num_workers: int = 3,
    timeout: int = 60,
    runs_per_query: int = 3,
    trigger_threshold: float = 0.5,
    model: Optional[str] = None,
    output_dir: Optional[Path] = None,
    verbose: bool = False,
) -> dict:
    """Run the optimization loop."""
    eval_set = json.loads(eval_set_path.read_text())
    name, original_description, content = parse_skill_md(skill_path)

    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)

    current_description = original_description
    best_description = original_description
    best_score = 0.0
    history = []

    for round_num in range(1, max_rounds + 1):
        if verbose:
            print(f"\n{'='*60}", file=sys.stderr)
            print(f"Round {round_num}/{max_rounds}", file=sys.stderr)
            print(f"Description: {current_description[:100]}...", file=sys.stderr)
            print(f"{'='*60}", file=sys.stderr)

        # Step 1: Evaluate
        if verbose:
            print(f"  Evaluating...", file=sys.stderr)

        eval_results = run_eval(
            eval_set=eval_set,
            skill_name=name,
            description=current_description,
            num_workers=num_workers,
            timeout=timeout,
            runs_per_query=runs_per_query,
            trigger_threshold=trigger_threshold,
            model=model,
        )

        summary = eval_results["summary"]
        score = summary["passed"] / summary["total"] if summary["total"] > 0 else 0

        if verbose:
            print(f"  Score: {score:.1%} ({summary['passed']}/{summary['total']})", file=sys.stderr)

        round_record = {
            "round": round_num,
            "description": current_description,
            "score": score,
            "eval_results": eval_results,
            "timestamp": datetime.now().isoformat(),
        }

        # Track best
        if score > best_score:
            best_score = score
            best_description = current_description
            if verbose:
                print(f"  New best! Score: {best_score:.1%}", file=sys.stderr)

        # Save round results
        if output_dir:
            round_file = output_dir / f"round_{round_num}.json"
            round_file.write_text(json.dumps(round_record, indent=2))

        history.append(round_record)

        # Check if we hit the target
        if score >= target_score:
            if verbose:
                print(f"\n  Target score {target_score:.1%} reached!", file=sys.stderr)
            break

        # Step 2: Improve (skip on last round)
        if round_num < max_rounds:
            if verbose:
                print(f"  Improving description...", file=sys.stderr)

            try:
                new_description = improve_description(
                    current_description, eval_results, model
                )
                if new_description and new_description != current_description:
                    current_description = new_description
                    if verbose:
                        print(f"  New description: {new_description[:100]}...", file=sys.stderr)
                else:
                    if verbose:
                        print(f"  No improvement suggested, stopping.", file=sys.stderr)
                    break
            except Exception as e:
                print(f"  Warning: improvement failed: {e}", file=sys.stderr)
                break

    output = {
        "skill_name": name,
        "original_description": original_description,
        "best_description": best_description,
        "best_score": best_score,
        "rounds": len(history),
        "history": history,
        "timestamp": datetime.now().isoformat(),
    }

    if output_dir:
        (output_dir / "loop_results.json").write_text(json.dumps(output, indent=2))

    return output


def main():
    parser = argparse.ArgumentParser(
        description="Run eval→improve→re-eval optimization loop"
    )
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--max-rounds", type=int, default=5, help="Maximum optimization rounds")
    parser.add_argument("--target-score", type=float, default=1.0, help="Stop when this score is reached")
    parser.add_argument("--num-workers", type=int, default=3, help="Parallel workers for eval")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model to use")
    parser.add_argument("--output-dir", default=None, help="Directory for round-by-round output")
    parser.add_argument("--apply-best", action="store_true", help="Apply best description to SKILL.md")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    skill_path = Path(args.skill_path)
    output_dir = Path(args.output_dir) if args.output_dir else None

    results = run_loop(
        skill_path=skill_path,
        eval_set_path=Path(args.eval_set),
        max_rounds=args.max_rounds,
        target_score=args.target_score,
        num_workers=args.num_workers,
        timeout=args.timeout,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
        output_dir=output_dir,
        verbose=args.verbose,
    )

    if args.verbose:
        print(f"\nFinal Results:", file=sys.stderr)
        print(f"  Original: {results['original_description'][:80]}...", file=sys.stderr)
        print(f"  Best:     {results['best_description'][:80]}...", file=sys.stderr)
        print(f"  Score:    {results['best_score']:.1%}", file=sys.stderr)
        print(f"  Rounds:   {results['rounds']}", file=sys.stderr)

    if args.apply_best:
        name, desc, _ = parse_skill_md(skill_path)
        skill_md = skill_path / "SKILL.md"
        text = skill_md.read_text()
        text = text.replace(f"description: {desc}", f"description: {results['best_description']}", 1)
        skill_md.write_text(text)
        print(f"Applied best description to SKILL.md", file=sys.stderr)

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
