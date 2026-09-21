#!/usr/bin/env python3
"""Audit and write SOURCE.md provenance files for Agent skills."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from datetime import date
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Iterable


SOURCE_NAMES = ("SOURCE.md", "source.md", "souce.md")
GITHUB_URL_RE = re.compile(r"https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:\.git)?(?:/[\w./-]*)?")
NPX_RE = re.compile(r"npx\s+skills(?:@latest)?\s+add\s+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)")
AUTHOR_RE = re.compile(r"^\s*author:\s*['\"]?([^'\"\n]+)['\"]?\s*$", re.MULTILINE)
DERIVED_RE = re.compile(r"derived from \[([^\]]+)\]\((https?://[^)]+)\)", re.IGNORECASE)


@dataclass
class SourceInfo:
    skill: str
    path: Path
    origin: str = "Unknown"
    repository: str | None = None
    creator: str | None = None
    author: str | None = None
    group: str | None = None
    group_prefix: str | None = None
    source_reference: str | None = None
    existing_source: Path | None = None
    github_candidates: list[str] = field(default_factory=list)
    evidence: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "skill": self.skill,
            "path": str(self.path),
            "origin": self.origin,
            "repository": self.repository,
            "creator": self.creator,
            "author": self.author,
            "group": self.group,
            "group_prefix": self.group_prefix,
            "source_reference": self.source_reference,
            "existing_source": str(self.existing_source) if self.existing_source else None,
            "github_candidates": self.github_candidates,
            "evidence": self.evidence,
        }


def default_skills_root() -> Path:
    codex_home = os.environ.get("CODEX_HOME")
    if codex_home:
        return Path(codex_home).expanduser() / "skills"
    return Path.home() / ".codex" / "skills"


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="replace")


def source_file(skill_dir: Path) -> Path | None:
    for name in SOURCE_NAMES:
        candidate = skill_dir / name
        if candidate.exists():
            return candidate
    return None


def parse_source_fields(path: Path) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in read_text(path).splitlines():
        if not line.startswith("- ") or ":" not in line:
            continue
        key, value = line[2:].split(":", 1)
        fields[key.strip().lower()] = value.strip()
    return fields


def iter_skill_dirs(root: Path, include_system: bool = False) -> Iterable[Path]:
    if not root.exists():
        return []
    paths = [path for path in root.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()]
    if include_system:
        system_root = root / ".system"
        if system_root.is_dir():
            paths.extend(path for path in system_root.iterdir() if path.is_dir() and (path / "SKILL.md").is_file())
    return sorted(paths)


def normalize_repo(value: str) -> str:
    value = value.rstrip("/.,)")
    if value.endswith(".git"):
        value = value[:-4]
    return value


def detect_git_remote(skill_dir: Path) -> str | None:
    if not (skill_dir / ".git").exists():
        return None
    try:
        result = subprocess.run(
            ["git", "-C", str(skill_dir), "remote", "get-url", "origin"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def github_token(token_env: str | None = None, use_gh_auth: bool = True) -> str | None:
    token = os.environ.get(token_env or "") if token_env else None
    if token:
        return token
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token or not use_gh_auth:
        return token
    gh = shutil.which("gh")
    if not gh:
        return None
    try:
        result = subprocess.run(
            [gh, "auth", "token"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def github_request(url: str, token_env: str | None = None, use_gh_auth: bool = True) -> dict[str, object]:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "ming-skill-source-manager",
    }
    token = github_token(token_env=token_env, use_gh_auth=use_gh_auth)
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=15) as response:
        payload = response.read().decode("utf-8")
    data = json.loads(payload)
    if not isinstance(data, dict):
        raise ValueError("GitHub response was not an object")
    return data


def github_search_repositories(
    skill_name: str,
    max_results: int,
    token_env: str | None = None,
    use_gh_auth: bool = True,
) -> list[dict[str, object]]:
    query = f"{skill_name} in:name"
    params = urllib.parse.urlencode({"q": query, "sort": "stars", "order": "desc", "per_page": max_results})
    data = github_request(f"https://api.github.com/search/repositories?{params}", token_env=token_env, use_gh_auth=use_gh_auth)
    items = data.get("items", [])
    if not isinstance(items, list):
        return []
    return [item for item in items if isinstance(item, dict)]


def apply_github_search(
    info: SourceInfo,
    max_results: int,
    token_env: str | None = None,
    use_gh_auth: bool = True,
) -> None:
    if info.origin != "Unknown":
        return
    try:
        items = github_search_repositories(
            info.skill,
            max_results=max_results,
            token_env=token_env,
            use_gh_auth=use_gh_auth,
        )
    except (OSError, TimeoutError, ValueError, http.client.IncompleteRead, urllib.error.URLError, urllib.error.HTTPError) as exc:
        info.evidence.append(f"GitHub search failed for skill name `{info.skill}`: {exc}")
        return
    candidates: list[str] = []
    exact_match: str | None = None
    for item in items:
        full_name = item.get("full_name")
        html_url = item.get("html_url")
        name = item.get("name")
        if not isinstance(full_name, str) or not isinstance(html_url, str):
            continue
        candidates.append(html_url)
        if isinstance(name, str) and name.lower() == info.skill.lower():
            exact_match = html_url
    info.github_candidates = candidates
    if exact_match:
        info.origin = "GitHub candidate"
        info.repository = exact_match
        info.evidence.append("GitHub repository search found an exact repository-name candidate")
    elif candidates:
        info.origin = "GitHub search candidates"
        info.source_reference = candidates[0]
        info.evidence.append("GitHub repository search found candidate repositories by skill name")
    else:
        info.evidence.append("GitHub repository search found no candidates by skill name")


def infer_source(skill_dir: Path) -> SourceInfo:
    info = SourceInfo(skill=skill_dir.name, path=skill_dir)
    existing = source_file(skill_dir)
    if existing:
        info.existing_source = existing
        info.evidence.append(f"Existing provenance file: {existing.name}")
        fields = parse_source_fields(existing)
        info.origin = fields.get("origin", info.origin)
        repository = fields.get("repository")
        if repository and not repository.lower().startswith("unknown"):
            info.repository = repository
        info.creator = fields.get("creator") or info.creator
        info.author = fields.get("author metadata") or info.author
        info.group = fields.get("group") or info.group
        info.group_prefix = fields.get("group prefix") or info.group_prefix
        info.source_reference = fields.get("source reference") or info.source_reference

    texts: list[tuple[str, str]] = []
    for name in ("SKILL.md", "README.md", "README.en.md"):
        path = skill_dir / name
        if path.is_file():
            texts.append((name, read_text(path)))
    combined = "\n".join(text for _, text in texts)

    remote = detect_git_remote(skill_dir)
    if remote:
        info.origin = "GitHub" if "github.com" in remote else "Git remote"
        info.repository = normalize_repo(remote)
        info.evidence.append("Local Git remote found")

    github_match = GITHUB_URL_RE.search(combined)
    if github_match and not info.repository:
        owner, repo = github_match.groups()
        info.origin = "GitHub"
        info.repository = f"https://github.com/{owner}/{repo}"
        info.evidence.append("GitHub URL found in installed files")

    npx_match = NPX_RE.search(combined)
    if npx_match and not info.repository:
        info.origin = "GitHub"
        info.repository = f"https://github.com/{npx_match.group(1)}"
        info.evidence.append("Agent Skills install command found in installed files")

    author_match = AUTHOR_RE.search(combined)
    if author_match:
        info.author = author_match.group(1).strip()
        if info.origin == "Unknown":
            info.origin = "Third-party author metadata"
        info.evidence.append("Author metadata found in SKILL.md")

    derived_match = DERIVED_RE.search(combined)
    if derived_match:
        info.source_reference = derived_match.group(2)
        if info.origin == "Unknown":
            info.origin = "Third-party conceptual source"
        info.evidence.append(f"Conceptual source reference found: {derived_match.group(1)}")

    if skill_dir.parent.name == ".system":
        info.origin = "Codex system skill"
        info.group = "codex-system-skills"
        info.group_prefix = ".system/"
        info.evidence.append("Skill directory is under the Codex system skills folder")

    if skill_dir.name.startswith("lark-"):
        info.group = "lark-skill-suite"
        info.group_prefix = "lark-"
        if info.origin == "Unknown":
            info.origin = "Third-party skill"
        info.evidence.append("Skill name matches lark-* group rule")

    if skill_dir.name.startswith("ming-"):
        info.group = "ming-local-skills"
        info.group_prefix = "ming-"
        if info.origin == "Unknown":
            info.origin = "User-created local skill"
        info.evidence.append("Skill name matches ming-* local skill group rule")

    if not info.evidence:
        info.evidence.append("No provenance signal found in installed files")
    return info


def render_source(info: SourceInfo, checked_on: str | None = None) -> str:
    checked = checked_on or date.today().isoformat()
    repository = info.repository
    if not repository:
        if info.origin == "User-created local skill":
            repository = "Not imported from GitHub"
        else:
            repository = "Unknown from installed files"
    lines = ["# Source", ""]
    fields = [
        ("Skill", info.skill),
        ("Origin", info.origin),
        ("Group", info.group),
        ("Group prefix", info.group_prefix),
        ("Creator", info.creator),
        ("Author metadata", info.author),
        ("Source reference", info.source_reference),
        ("Repository", repository),
        ("Checked on", checked),
    ]
    for key, value in fields:
        if value:
            lines.append(f"- {key}: {value}")
    lines.extend(["", "## Evidence", ""])
    for item in info.evidence:
        lines.append(f"- {item}")
    if info.github_candidates:
        lines.extend(["", "## GitHub Search Candidates", ""])
        for candidate in info.github_candidates:
            lines.append(f"- {candidate}")
    lines.append("")
    return "\n".join(lines)


def write_source(info: SourceInfo, overwrite: bool = False) -> Path:
    destination = info.path / "SOURCE.md"
    if destination.exists() and not overwrite:
        raise SystemExit(f"Refusing to overwrite existing file: {destination}")
    destination.write_text(render_source(info), encoding="utf-8")
    return destination


def print_table(items: list[SourceInfo]) -> None:
    print("skill\torigin\tgroup\trepository/source")
    for item in items:
        source = item.repository or item.source_reference or item.author or ""
        print(f"{item.skill}\t{item.origin}\t{item.group or ''}\t{source}")


def audit(args: argparse.Namespace) -> None:
    root = Path(args.skills_root).expanduser()
    items = [infer_source(path) for path in iter_skill_dirs(root, include_system=args.include_system)]
    if args.github_search_unknown:
        for item in items:
            apply_github_search(
                item,
                max_results=args.github_max_results,
                token_env=args.github_token_env,
                use_gh_auth=not args.no_github_gh_auth,
            )
    if args.write:
        for item in items:
            if item.origin == "Unknown" and not args.write_unknown:
                continue
            existing_fields = parse_source_fields(item.path / "SOURCE.md") if (item.path / "SOURCE.md").exists() else {}
            existing_origin = existing_fields.get("origin", "")
            should_refresh_unknown = args.github_search_unknown and existing_origin == "Unknown" and item.origin != "Unknown"
            if (item.path / "SOURCE.md").exists() and not args.overwrite and not should_refresh_unknown:
                continue
            write_source(item, overwrite=args.overwrite or should_refresh_unknown)
    if args.json:
        print(json.dumps([item.to_dict() for item in items], ensure_ascii=False, indent=2))
    else:
        print_table(items)


def write_one(args: argparse.Namespace) -> None:
    skill_dir = Path(args.skill).expanduser()
    if not (skill_dir / "SKILL.md").is_file():
        raise SystemExit(f"Not a skill directory: {skill_dir}")
    info = infer_source(skill_dir)
    info.origin = args.origin or info.origin
    info.repository = args.repository or info.repository
    info.creator = args.creator or info.creator
    info.author = args.author or info.author
    info.group = args.group or info.group
    info.group_prefix = args.group_prefix or info.group_prefix
    info.source_reference = args.source_reference or info.source_reference
    if args.evidence:
        info.evidence.extend(args.evidence)
    destination = write_source(info, overwrite=args.overwrite)
    print(destination)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    audit_parser = subparsers.add_parser("audit", help="scan a skills root")
    audit_parser.add_argument("--skills-root", default=str(default_skills_root()))
    audit_parser.add_argument("--include-system", action="store_true", help="also scan <skills-root>/.system")
    audit_parser.add_argument("--github-search-unknown", action="store_true", help="search GitHub by skill name for entries still marked Unknown")
    audit_parser.add_argument("--github-max-results", type=int, default=5, help="maximum GitHub repository candidates per unknown skill")
    audit_parser.add_argument("--github-token-env", help="environment variable containing a GitHub token")
    audit_parser.add_argument("--no-github-gh-auth", action="store_true", help="do not use `gh auth token` for GitHub search")
    audit_parser.add_argument("--write", action="store_true", help="write SOURCE.md for detected skills")
    audit_parser.add_argument("--write-unknown", action="store_true", help="also write Unknown records")
    audit_parser.add_argument("--overwrite", action="store_true", help="replace existing SOURCE.md files")
    audit_parser.add_argument("--json", action="store_true")
    audit_parser.set_defaults(func=audit)

    write_parser = subparsers.add_parser("write", help="write one skill SOURCE.md")
    write_parser.add_argument("--skill", required=True, help="path to one skill directory")
    write_parser.add_argument("--origin", help="source type, such as GitHub or User-created local skill")
    write_parser.add_argument("--repository")
    write_parser.add_argument("--creator")
    write_parser.add_argument("--author")
    write_parser.add_argument("--group")
    write_parser.add_argument("--group-prefix")
    write_parser.add_argument("--source-reference")
    write_parser.add_argument("--evidence", action="append")
    write_parser.add_argument("--overwrite", action="store_true")
    write_parser.set_defaults(func=write_one)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
