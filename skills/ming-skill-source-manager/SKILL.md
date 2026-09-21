---
name: ming-skill-source-manager
description: "Manage Agent skill provenance. Use when creating or importing a skill and a SOURCE.md record should be added, when auditing a skills library to identify sources with existing SOURCE.md files, keyword matches, author metadata, README install hints, GitHub URLs, or local Git remotes, or when backfilling SOURCE.md for every installed skill including Codex system skills. Do not use for executing another skill's actual task."
---

# Ming Skill Source Manager

Keep a skills library manageable by recording where each skill came from and by auditing existing skills for provenance signals.

Use the canonical filename `SOURCE.md`. When auditing old directories, also recognize `source.md` and `souce.md` as legacy provenance files, but create or update `SOURCE.md` unless the user explicitly asks otherwise.

## Modes

### Add Source For One Skill

Use this when a user creates, installs, imports, copies, or manually identifies one skill's provenance.

1. Identify the skill directory. It must contain `SKILL.md`.
2. Determine the source type from the user's statement and local evidence:
   - `User-created local skill` when the user says they created it locally.
   - `GitHub` when there is a repository URL, an install command with `<owner>/<repo>`, or a local Git remote.
   - `Third-party skill` when the user identifies it as third-party but no repository is known.
   - `Third-party author metadata` when the only evidence is author metadata.
   - `Unknown` when there is no reliable evidence.
3. Preserve existing provenance if a `SOURCE.md`, `source.md`, or `souce.md` file exists. Do not overwrite without checking whether the new evidence is stronger.
4. Write concise, factual fields: skill name, origin, optional creator or author, optional group, optional repository, optional default branch and remote HEAD, check date, and evidence.
5. Report the file path and whether the source was confirmed or inferred.

For deterministic writes, prefer:

```bash
python scripts/manage_sources.py write --skill <skill-dir> --origin <origin> [--repository <url>] [--creator <name>] [--group <group>]
```

### Audit A Skills Library

Use this when a user wants to organize their skills library or find third-party/imported skills.

1. Choose the skills root from the user's path. If omitted, use the active `$CODEX_HOME/skills` or `~/.codex/skills`.
2. Run the scanner first without writing:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root>
```

3. Review the evidence classes:
   - Existing provenance file.
   - GitHub URL or `npx skills add` command in README or `SKILL.md`.
   - Local `.git` remote.
   - Frontmatter author metadata.
   - Prefix/group rules, such as `lark-*` belonging to one suite when the user confirms that rule, or `ming-*` for Ming's self-created local skills.
   - Codex system skill placement under `.system`.
   - Conceptual source links such as `derived from ...`.
   - Optional GitHub repository search by skill name for entries still marked `Unknown`.
4. If the user asked to update files, write only records supported by evidence or explicit user statements:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root> --write
```

5. Summarize confirmed GitHub sources, third-party inferred sources, user-created local skills, unknown entries, and any skipped directories.

### Backfill Every Installed Skill

Use this when a user wants every existing skill directory to have `SOURCE.md`, including Codex system skills under `.system`.

1. Run a dry audit that includes system skills:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root> --include-system
```

2. Write missing files for all detected skills, including conservative `Unknown` records where evidence is insufficient:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root> --include-system --write --write-unknown
```

3. Do not overwrite existing `SOURCE.md` unless the user asks to refresh or normalize existing records.
4. Verify the count of skill directories with `SKILL.md` equals the count of `SOURCE.md` files in those directories.
5. Report how many records were created and which skills remain unknown.

### Resolve Unknown Skills With GitHub Search

Use this after a local audit leaves skills marked `Unknown` and the user asks to search GitHub for possible sources.

1. Search only unresolved `Unknown` entries unless the user asks for a broader refresh:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root> --include-system --github-search-unknown
```

2. If writing results, refresh only existing `Unknown` records and do not overwrite confirmed sources:

```bash
python scripts/manage_sources.py audit --skills-root <skills-root> --include-system --github-search-unknown --write --write-unknown
```

3. Treat GitHub search results as candidates. Use `Origin: GitHub candidate` for an exact repository-name match and `Origin: GitHub search candidates` when only looser candidates are found.
4. Do not claim a candidate is the installed source until repository content, local install evidence, or the user confirms it.
5. Report any skills where GitHub search found no candidates or failed due to network/rate limits. The script uses `GITHUB_TOKEN`, `GH_TOKEN`, a named token env var, or `gh auth token` when available; never print or write the token.

## Evidence Rules

- A GitHub URL in README or `SKILL.md` is strong evidence of GitHub provenance, but do not claim the installed files are current unless remote HEAD or local Git commit was checked.
- A GitHub search result for an unknown skill is weaker evidence than installed-file evidence. Record it as a candidate, not a confirmed repository, unless the match is later verified.
- Author metadata identifies an author, not a repository.
- A shared prefix rule, such as `lark-*`, is valid only when the user states or confirms the group meaning. `ming-*` means Ming's self-created local skills when that local convention is in use.
- A skill under `.system` is a Codex system skill. Record `Origin: Codex system skill`, `Group: codex-system-skills`, and do not rename or move it.
- User statements are valid provenance evidence and should be named as such in `SOURCE.md`.
- Do not write secrets, tokens, private clone URLs with credentials, shell history, or unrelated local paths into provenance files.

## Git And Network Checks

Local Git metadata checks are safe and automatic. Remote checks with `git ls-remote` and GitHub repository search may use the network; run them only when the user asks for current remote verification, asks to resolve unknown sources, or when provenance confidence depends on it. GitHub search may use `gh auth token` if the GitHub CLI is already logged in. If a network Git check times out, follow the host environment's dependency/network guidance before changing repository assumptions.

## Output

Each `SOURCE.md` should be short and readable:

```markdown
# Source

- Skill: <name>
- Origin: <origin>
- Group: <optional-group>
- Creator: <optional-creator>
- Author metadata: <optional-author>
- Repository: <url-or-unknown>
- Checked on: <YYYY-MM-DD>

## Evidence

- <evidence item>

## GitHub Search Candidates

- <candidate-url-when-unconfirmed>
```

## 资源导航

- `scripts/manage_sources.py`: audit a skills root or write canonical `SOURCE.md` files.
