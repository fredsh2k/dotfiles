#!/usr/bin/env python3.12
"""Improve a skill description using the Copilot SDK.

Sends a prompt to Copilot asking it to improve the description based on
evaluation results (false positives, false negatives). Returns the improved
description text.

Requires: pip install github-copilot-sdk
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Optional

from scripts.utils import parse_skill_md

IMPROVE_PROMPT = """You are a skill description optimizer. A "skill" is a plugin that an AI coding assistant loads when its one-line description matches the user's query.

The current description is:
---
{description}
---

Here are the evaluation results showing which queries correctly/incorrectly triggered the skill:

{eval_results}

Your job: rewrite the description so that:
1. Queries marked should_trigger=true AND pass=false → the new description triggers for these (fix false negatives)
2. Queries marked should_trigger=false AND pass=false → the new description does NOT trigger for these (fix false positives)
3. Queries that already pass remain working

Rules:
- Output ONLY the new description text, nothing else
- Keep it concise (1-3 sentences)
- Be specific about what the skill does and when to use it
- Include key trigger words that match the should_trigger=true queries
- Exclude or disambiguate from should_trigger=false query patterns

New description:"""


async def improve_description_async(
    current_description: str,
    eval_results: dict,
    model: Optional[str] = None,
) -> str:
    """Use Copilot SDK to generate an improved description."""
    from copilot import CopilotClient, PermissionHandler
    from copilot.generated.session_events import SessionEventType

    # Format eval results for the prompt
    lines = []
    for r in eval_results.get("results", []):
        status = "PASS" if r["pass"] else "FAIL"
        lines.append(
            f"  [{status}] should_trigger={r['should_trigger']} "
            f"rate={r['trigger_rate']:.1%}: {r['query']}"
        )
    eval_text = "\n".join(lines)

    prompt = IMPROVE_PROMPT.format(
        description=current_description,
        eval_results=eval_text,
    )

    client = CopilotClient()
    await client.start()

    config = {
        "streaming": True,
        "on_permission_request": PermissionHandler.approve_all,
    }
    if model:
        config["model"] = model

    session = await client.create_session(config)

    collected_text = []

    def handle_event(event):
        if event.type == SessionEventType.ASSISTANT_MESSAGE_DELTA:
            delta = getattr(event.data, "delta_content", "") or ""
            collected_text.append(delta)
        elif event.type == SessionEventType.ASSISTANT_MESSAGE:
            content = getattr(event.data, "content", "") or ""
            if content and not collected_text:
                collected_text.append(content)

    session.on(handle_event)

    try:
        await asyncio.wait_for(
            session.send_and_wait({"prompt": prompt}),
            timeout=180,
        )
    except asyncio.TimeoutError:
        print("Warning: session timed out", file=sys.stderr)

    await client.stop()

    result = "".join(collected_text).strip()
    # Clean up any markdown formatting the model might add
    if result.startswith('"') and result.endswith('"'):
        result = result[1:-1]
    if result.startswith("```") and result.endswith("```"):
        result = result.strip("`").strip()

    return result


def improve_description(
    current_description: str,
    eval_results: dict,
    model: Optional[str] = None,
) -> str:
    """Synchronous wrapper for improve_description_async."""
    return asyncio.run(
        improve_description_async(current_description, eval_results, model)
    )


def main():
    parser = argparse.ArgumentParser(description="Improve a skill description using Copilot SDK")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--eval-results", required=True, help="Path to eval results JSON")
    parser.add_argument("--model", default=None, help="Model to use")
    parser.add_argument("--apply", action="store_true", help="Apply the new description to SKILL.md")
    args = parser.parse_args()

    skill_path = Path(args.skill_path)
    eval_results = json.loads(Path(args.eval_results).read_text())

    name, description, content = parse_skill_md(skill_path)

    new_description = improve_description(description, eval_results, args.model)

    print(f"Current:  {description}", file=sys.stderr)
    print(f"Improved: {new_description}", file=sys.stderr)

    if args.apply:
        skill_md = skill_path / "SKILL.md"
        text = skill_md.read_text()
        text = text.replace(
            f"description: {description}",
            f"description: {new_description}",
            1,
        )
        skill_md.write_text(text)
        print("Applied new description to SKILL.md", file=sys.stderr)

    # Output just the new description for piping
    print(new_description)


if __name__ == "__main__":
    main()
