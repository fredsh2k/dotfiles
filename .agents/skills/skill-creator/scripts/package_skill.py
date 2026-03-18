#!/usr/bin/env python3.12
"""
Skill Installer - Installs a skill into ~/.copilot/skills/<name>/ or a project.

Usage:
    python3.12 scripts/package_skill.py <path/to/skill-folder>
    python3.12 scripts/package_skill.py <path/to/skill-folder> --project <repo-root>
    python3.12 scripts/package_skill.py --uninstall <skill-name>
    python3.12 scripts/package_skill.py --uninstall <skill-name> --project <repo-root>

Example:
    python3.12 scripts/package_skill.py skills/public/my-skill
    python3.12 scripts/package_skill.py skills/public/my-skill --project /path/to/repo
    python3.12 scripts/package_skill.py --uninstall my-skill
"""

import argparse
import fnmatch
import shutil
import sys
from pathlib import Path
from scripts.quick_validate import validate_skill

SKILLS_DIR = Path.home() / ".copilot" / "skills"

# Patterns to exclude when installing skills.
EXCLUDE_DIRS = {"__pycache__", "node_modules"}
EXCLUDE_GLOBS = {"*.pyc"}
EXCLUDE_FILES = {".DS_Store"}
# Directories excluded only at the skill root (not when nested deeper).
ROOT_EXCLUDE_DIRS = {"evals"}


def should_exclude(rel_path: Path) -> bool:
    """Check if a relative path should be excluded from installation."""
    parts = rel_path.parts
    if any(part in EXCLUDE_DIRS for part in parts):
        return True
    # Top-level directories to skip (e.g. evals/).
    if len(parts) > 0 and parts[0] in ROOT_EXCLUDE_DIRS:
        return True
    name = rel_path.name
    if name in EXCLUDE_FILES:
        return True
    return any(fnmatch.fnmatch(name, pat) for pat in EXCLUDE_GLOBS)


def _resolve_skills_dir(project_root: Path = None) -> Path:
    """Return the target skills directory — project-scoped or global."""
    if project_root:
        return project_root / ".github" / "copilot" / "skills"
    return SKILLS_DIR


def install_skill(skill_path: Path, project_root: Path = None) -> bool:
    """
    Validate and install a skill directory.

    If project_root is provided, installs to <project_root>/.github/copilot/skills/<name>/.
    Otherwise installs to ~/.copilot/skills/<name>/.

    Returns True on success, False on failure.
    """
    skill_path = Path(skill_path).resolve()

    if not skill_path.exists():
        print(f"❌ Error: Skill folder not found: {skill_path}")
        return False

    if not skill_path.is_dir():
        print(f"❌ Error: Path is not a directory: {skill_path}")
        return False

    if not (skill_path / "SKILL.md").exists():
        print(f"❌ Error: SKILL.md not found in {skill_path}")
        return False

    # Run validation before installing
    print("🔍 Validating skill...")
    valid, message = validate_skill(skill_path)
    if not valid:
        print(f"❌ Validation failed: {message}")
        print("   Please fix the validation errors before installing.")
        return False
    print(f"✅ {message}\n")

    skills_dir = _resolve_skills_dir(project_root)
    skill_name = skill_path.name
    dest = skills_dir / skill_name

    # Remove previous installation if present
    if dest.exists():
        print(f"♻️  Replacing existing installation at {dest}")
        shutil.rmtree(dest)

    dest.mkdir(parents=True, exist_ok=True)

    copied = 0
    skipped = 0
    try:
        for src_file in skill_path.rglob("*"):
            if not src_file.is_file():
                continue
            rel = src_file.relative_to(skill_path)
            if should_exclude(rel):
                print(f"  Skipped: {rel}")
                skipped += 1
                continue
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_file, target)
            print(f"  Copied:  {rel}")
            copied += 1
    except Exception as e:
        print(f"\n❌ Error installing skill: {e}")
        return False

    print(f"\n✅ Installed '{skill_name}' to {dest}")
    print(f"   {copied} file(s) copied, {skipped} skipped")
    return True


def uninstall_skill(skill_name: str, project_root: Path = None) -> bool:
    """Remove an installed skill from the appropriate skills directory."""
    skills_dir = _resolve_skills_dir(project_root)
    dest = skills_dir / skill_name
    if not dest.exists():
        print(f"❌ Skill '{skill_name}' is not installed (looked in {dest})")
        return False
    shutil.rmtree(dest)
    print(f"✅ Uninstalled skill '{skill_name}' from {dest}")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Install or uninstall a Copilot CLI skill.",
    )
    parser.add_argument(
        "skill_path",
        nargs="?",
        help="Path to the skill folder to install",
    )
    parser.add_argument(
        "--uninstall",
        metavar="SKILL_NAME",
        help="Uninstall a skill by name (e.g. --uninstall my-skill)",
    )
    parser.add_argument(
        "--project",
        metavar="REPO_ROOT",
        help="Install into a project repo at <REPO_ROOT>/.github/copilot/skills/ instead of globally",
    )
    args = parser.parse_args()

    project_root = Path(args.project).resolve() if args.project else None

    if args.uninstall:
        scope = f"project ({project_root})" if project_root else "global"
        print(f"🗑️  Uninstalling skill: {args.uninstall} ({scope})\n")
        ok = uninstall_skill(args.uninstall, project_root)
        sys.exit(0 if ok else 1)

    if not args.skill_path:
        parser.print_help()
        sys.exit(1)

    scope = f"project ({project_root})" if project_root else "global"
    print(f"📦 Installing skill: {args.skill_path} ({scope})\n")
    ok = install_skill(args.skill_path, project_root)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
