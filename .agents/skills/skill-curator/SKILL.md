---
name: skill-curator
description: Maintains the user's personal skill library. Skills are tracked in the dotfiles repo at ~/Code/Personal/dotfiles/.agents/skills/ and symlinked into ~/.agents/skills/. Use this skill PROACTIVELY at the end of any conversation where (a) you repeated a non-trivial multi-step workflow that wasn't covered by an existing skill, (b) the user gave you durable knowledge worth preserving across sessions (commands, file paths, internal tooling, gotchas, conventions), (c) an existing skill's instructions led you astray, were out of date, missed a step, or you had to deviate from them to succeed, or (d) the user explicitly asks to add, fix, improve, refactor, audit, or remove a skill. Also use when the user mentions "skill", "remember this", "save this for later", "next time", "you should know", or asks why a skill isn't being triggered.
---

# skill-curator

Curates the user's personal Agent Skills library so future sessions are faster and more accurate. Two modes: **propose new skills** when a reusable pattern emerged, and **patch existing skills** when one underperformed.

## Conventions

- **Single source of truth:** every skill lives in `~/Code/Personal/dotfiles/.agents/skills/<skill-name>/SKILL.md` and is symlinked into `~/.agents/skills/<skill-name>` so it loads at runtime AND is tracked in git.
- Exception: a skill may itself be a symlink to a different repo (e.g. `moda-linter` → its own work repo). Leave those alone — don't move them into dotfiles.
- Skill names are kebab-case; dir name must match the `name:` in frontmatter.
- Each skill is a markdown file with YAML frontmatter:
  ```yaml
  ---
  name: <kebab-case, matches dir>
  description: <one rich paragraph: what + when to load. Trigger words matter — the agent only sees the description until it loads the skill, so pack it with concrete keywords, file names, error strings, and user phrasings.>
  ---
  ```
- Body is plain markdown. Keep it terse and operational: commands, paths, gotchas, decision trees. No filler prose.
- Optional bundled files (scripts, references, templates) go alongside `SKILL.md` in the same directory and are referenced by relative path.
- The user's broader norms (from `~/.config/opencode/AGENTS.md` and `~/.agents/instructions/fredsh2k.instructions.md`) apply to anything the skill tells the agent to do: `rg` over `grep`, `fd` over `find`, `sd` over `sed`, `rip` over `rm`, no `git push` without approval, etc. Don't restate these in skills — inherit them.

## Trigger heuristics (when to act without being asked)

At the end of a turn, silently ask yourself:

1. **Was there a multi-step workflow** (≥3 distinct steps, or any non-obvious command sequence) the user walked me through that I'll likely need again?
2. **Did the user share infra-specific knowledge** — internal hostnames, vault paths, kubectl contexts, API endpoints, custom CLIs, file-layout conventions, "we always do X this way"?
3. **Did I load a skill and then have to work around it** — wrong path, deprecated flag, missing step, vague description that mis-triggered?
4. **Did I fail to load a skill that would have helped** — discovered an existing skill mid-task, or noticed a description that didn't match the user's phrasing?

If any of 1–4 → surface a one-line proposal at the end of your reply ("Want me to capture this as a `<name>` skill?" or "The `<name>` skill description didn't match how you phrased this — want me to tighten it?"). Don't be noisy; one proposal per turn max. If the user has been working on routine tasks already covered by skills, stay silent.

**Always require explicit user approval before creating, editing, or deleting a skill file.** Show a diff or a draft first.

## Workflow: propose & create a new skill

1. Pick a kebab-case name. Check for collisions: `ls ~/.agents/skills/`.
2. Draft the YAML frontmatter. The `description` is the most important field — it's the only thing the loader sees. Include:
   - What the skill does (one clause).
   - Concrete trigger words: tool names, file names, error strings, common user phrasings ("when the user says X", "when you see Y").
   - Rough scope so it doesn't over-trigger.
3. Draft the body. Sections to include only if relevant: setup/auth, common commands, decision tree, gotchas, examples. Skip "introduction" and "conclusion".
4. Show the draft to the user for approval. On approval, `mkdir -p ~/.agents/skills/<name>/` and `Write` the `SKILL.md`.
5. If the skill bundles scripts/templates, create them in the same dir. Make scripts executable (`chmod +x`).
6. After writing, remind the user the skill is available immediately in new sessions (skills are loaded from disk on agent startup).

## Workflow: patch an existing skill

When a skill misfired:

1. Identify the failure mode:
   - **Didn't trigger** → description lacks the user's phrasing/keywords. Fix the `description`.
   - **Triggered wrongly** → description too broad. Narrow it; add disambiguation ("not for X").
   - **Instructions wrong/stale** → fix body. Note what changed and why in the edit.
   - **Missing step** → add it. If the missing step is environment-specific, mark it as such.
2. Read the current `SKILL.md` first. Show the proposed diff.
3. On approval, `Edit` the file. Prefer minimal edits over rewrites. Preserve the user's voice if the skill was hand-written.
4. If a skill has decayed badly (multiple failures, stale tools, contradicts current setup), propose deletion: `rip ~/.agents/skills/<name>/`.

## Drafting a good `description`

The loader matches the description against the user's request. Optimize for recall:

- Lead with what the skill does, in the user's likely vocabulary.
- Enumerate trigger phrases: "Use this skill when the user mentions X, Y, Z, or asks to A, B, C."
- Include error strings and tool names verbatim.
- Mention file paths and command names the skill references.
- One paragraph, ~40–120 words. Longer is fine if it adds real triggers; pure prose is not.

Compare:

> **Bad:** `description: Helps with deployments.`
>
> **Good:** `description: Lints Kubernetes configuration bundles for GitHub's Moda platform. Use whenever the user needs to validate, lint, check, or fix Moda config files, secrets inventory files, kustomize overlays, deployment.yaml, build_options.yaml, Dockerfiles, or YAML syntax. Also use when the user mentions Moda deployment issues, Kubernetes manifest problems, config errors, CI lint failures, moda-linter rule violations, or wants to understand why a Moda check is failing.`

## Anti-patterns — do NOT create skills for

- One-off tasks unlikely to recur.
- Things already covered by an existing skill (audit first with `ls ~/.agents/skills/` and read sibling `SKILL.md` files).
- Generic programming knowledge the model already has.
- Anything purely tied to the current repo — that belongs in the repo's `AGENTS.md`, not a global skill.
- Restating user-wide norms already in `~/.config/opencode/AGENTS.md` or `~/.agents/instructions/fredsh2k.instructions.md`.

## Periodic audit (when user asks "audit my skills")

1. `ls ~/.agents/skills/` and read each `SKILL.md`'s frontmatter.
2. Flag: duplicates, vague descriptions, contradicting skills, skills referencing tools not on PATH (`command -v <tool>`), skills with stale paths.
3. Report findings as a list with proposed actions (patch / merge / delete). Do nothing without approval.
