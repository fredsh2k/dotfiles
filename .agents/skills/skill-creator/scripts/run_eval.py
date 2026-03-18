#!/usr/bin/env python3.12
"""Run trigger evaluation for a skill description using the Copilot SDK.

Tests whether a skill's description causes Copilot to trigger (read the skill)
for a set of queries. Outputs results as JSON.

Requires: pip install github-copilot-sdk
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import shutil
import sys
import tempfile
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Optional

from scripts.utils import parse_skill_md

COPILOT_SKILLS_DIR = Path.home() / ".copilot" / "skills"


def _create_temp_skill(skill_name: str, description: str) -> "tuple[str, Path]":
    """Create a temporary skill in ~/.copilot/skills/ for triggering tests.

    Returns (unique_name, skill_path).
    """
    unique_id = uuid.uuid4().hex[:8]
    clean_name = f"{skill_name}-eval-{unique_id}"
    skill_dir = COPILOT_SKILLS_DIR / clean_name
    skill_dir.mkdir(parents=True, exist_ok=True)

    # Use YAML block scalar to avoid breaking on quotes in description
    indented_desc = "\n  ".join(description.split("\n"))
    skill_content = (
        f"---\n"
        f"name: {clean_name}\n"
        f"description: |\n"
        f"  {indented_desc}\n"
        f"---\n\n"
        f"# {skill_name}\n\n"
        f"This skill handles: {description}\n"
    )
    (skill_dir / "SKILL.md").write_text(skill_content)
    return clean_name, skill_dir


def _cleanup_temp_skill(skill_dir: Path):
    """Remove a temporary skill directory."""
    if skill_dir.exists():
        shutil.rmtree(skill_dir)


def run_single_query_sync(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    model: Optional[str] = None,
) -> bool:
    """Run a single query and return whether the skill was triggered.

    Creates a temporary skill, starts a Copilot SDK session,
    sends the query, and watches events for skill invocation.
    """
    return asyncio.run(
        _run_single_query_async(query, skill_name, skill_description, timeout, model)
    )


async def _run_single_query_async(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    model: Optional[str] = None,
) -> bool:
    """Async implementation of the single-query trigger test."""
    from copilot import CopilotClient, PermissionHandler
    from copilot.generated.session_events import SessionEventType

    clean_name, skill_dir = _create_temp_skill(skill_name, skill_description)
    triggered = False

    try:
        client = CopilotClient()
        await client.start()

        config = {
            "streaming": True,
            "on_permission_request": PermissionHandler.approve_all,
        }
        if model:
            config["model"] = model

        session = await client.create_session(config)

        # Watch all events for skill invocation
        def handle_event(event):
            nonlocal triggered
            # Primary: SKILL_INVOKED event with name or path field
            if event.type == SessionEventType.SKILL_INVOKED:
                ev_name = getattr(event.data, "name", "") or ""
                ev_path = getattr(event.data, "path", "") or ""
                if clean_name in ev_name or clean_name in ev_path:
                    triggered = True
            # Fallback: check assistant messages for skill references
            elif event.type == SessionEventType.ASSISTANT_MESSAGE:
                content = getattr(event.data, "content", "") or ""
                if clean_name in content:
                    triggered = True
            elif event.type == SessionEventType.ASSISTANT_MESSAGE_DELTA:
                delta = getattr(event.data, "delta_content", "") or ""
                if clean_name in delta:
                    triggered = True

        session.on(handle_event)

        try:
            await asyncio.wait_for(
                session.send_and_wait({"prompt": query}),
                timeout=timeout,
            )
        except asyncio.TimeoutError:
            pass

        await client.stop()
    finally:
        _cleanup_temp_skill(skill_dir)

    return triggered


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: Optional[str] = None,
) -> dict:
    """Run the full eval set and return results."""
    results = []

    # Temporarily disable ALL other skills so only the temp eval skill is visible.
    # This prevents side effects (e.g., devportal opening a browser for Okta auth).
    # Move completely outside ~/.copilot/skills/ (dotfiles are still scanned).
    stash_dir = Path(tempfile.mkdtemp(prefix="skill-eval-stash-"))
    stashed_skills = []
    if COPILOT_SKILLS_DIR.exists():
        for skill_dir in COPILOT_SKILLS_DIR.iterdir():
            if skill_dir.is_dir() and not skill_dir.name.startswith('.'):
                dest = stash_dir / skill_dir.name
                shutil.move(str(skill_dir), str(dest))
                stashed_skills.append(skill_dir.name)

    try:
        with ProcessPoolExecutor(max_workers=num_workers) as executor:
            future_to_info = {}
            for item in eval_set:
                for run_idx in range(runs_per_query):
                    future = executor.submit(
                        run_single_query_sync,
                        item["query"],
                        skill_name,
                        description,
                        timeout,
                        model,
                    )
                    future_to_info[future] = (item, run_idx)

            query_triggers = {}  # type: dict[str, list[bool]]
            query_items = {}  # type: dict[str, dict]
            for future in as_completed(future_to_info):
                item, _ = future_to_info[future]
                query = item["query"]
                query_items[query] = item
                if query not in query_triggers:
                    query_triggers[query] = []
                try:
                    query_triggers[query].append(future.result())
                except Exception as e:
                    print(f"Warning: query failed: {e}", file=sys.stderr)
                    query_triggers[query].append(False)
    finally:
        # Restore all stashed skills
        for name in stashed_skills:
            src = stash_dir / name
            dest = COPILOT_SKILLS_DIR / name
            if src.exists() and not dest.exists():
                shutil.move(str(src), str(dest))
        shutil.rmtree(str(stash_dir), ignore_errors=True)

    for query, triggers in query_triggers.items():
        item = query_items[query]
        trigger_rate = sum(triggers) / len(triggers)
        should_trigger = item["should_trigger"]
        if should_trigger:
            did_pass = trigger_rate >= trigger_threshold
        else:
            did_pass = trigger_rate < trigger_threshold
        results.append({
            "query": query,
            "should_trigger": should_trigger,
            "trigger_rate": trigger_rate,
            "triggers": sum(triggers),
            "runs": len(triggers),
            "pass": did_pass,
        })

    passed = sum(1 for r in results if r["pass"])
    total = len(results)

    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {
            "total": total,
            "passed": passed,
            "failed": total - passed,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Run trigger evaluation for a skill description")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=3, help="Number of parallel workers")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model to use (default: SDK default)")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)

    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, content = parse_skill_md(skill_path)
    description = args.description or original_description

    if args.verbose:
        print(f"Evaluating: {description}", file=sys.stderr)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
    )

    if args.verbose:
        summary = output["summary"]
        print(f"Results: {summary['passed']}/{summary['total']} passed", file=sys.stderr)
        for r in output["results"]:
            status = "PASS" if r["pass"] else "FAIL"
            rate_str = f"{r['triggers']}/{r['runs']}"
            print(f"  [{status}] rate={rate_str} expected={r['should_trigger']}: {r['query'][:70]}", file=sys.stderr)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
