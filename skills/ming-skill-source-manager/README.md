# ming-skill-source-manager

## 有什么用

`ming-skill-source-manager` helps maintain provenance for a local Agent skills library. It writes a small `SOURCE.md` file beside each `SKILL.md`, then uses those files plus keyword, metadata, README, and Git evidence to organize where skills came from.

It is useful in two common cases:

- A new or imported skill should immediately get a source record.
- An existing skills library needs to be audited so user-created, GitHub-imported, third-party, grouped, and unknown skills are easier to manage.
- Every installed skill, including Codex system skills under `.system`, needs a conservative source record.
- Unknown skills need a best-effort GitHub search by skill name, with candidate repositories recorded separately from confirmed provenance.

## 安装

Copy this directory into an Agent skills folder. The skill has no package dependency beyond Python 3.10+ for the helper script.

If this skill is later published to GitHub, add the repository URL and install command here.

## 配置

No persistent configuration is required. The default skills root is `$CODEX_HOME/skills` or `~/.codex/skills`.

Do not store secrets, credentials, or private clone URLs with embedded credentials in `SOURCE.md`.

## 使用

Natural-language examples:

- “这个 skill 是我自己创建的，帮我写来源信息。”
- “我从 GitHub 导入了这个 skill，帮我补 `SOURCE.md`。”
- “扫描我的 skills 目录，找出第三方来源和未知来源。”
- “所有 `lark-*` 都是同一组第三方 skill，帮我统一记录来源。”
- “所有 `ming-*` 都是我本地创建的 skill，帮我统一记录来源。”
- “扫描所有已有 skill，包含系统自带的，给没有来源的补 `SOURCE.md`。”
- “对 Unknown skill 按名称去 GitHub 搜一下可能来源。”

Script examples:

```bash
python scripts/manage_sources.py audit --skills-root ~/.codex/skills
python scripts/manage_sources.py audit --skills-root ~/.codex/skills --write
python scripts/manage_sources.py audit --skills-root ~/.codex/skills --include-system --write --write-unknown
python scripts/manage_sources.py audit --skills-root ~/.codex/skills --include-system --github-search-unknown
python scripts/manage_sources.py audit --skills-root ~/.codex/skills --include-system --github-search-unknown --write --write-unknown
python scripts/manage_sources.py write --skill ~/.codex/skills/example-skill --origin "User-created local skill" --creator Ming
python scripts/manage_sources.py write --skill ~/.codex/skills/example-skill --origin GitHub --repository https://github.com/owner/repo
```

## 兼容性与依赖

The helper script uses Python 3.10+ and the standard library. Local Git remote discovery uses the `git` CLI when available. GitHub search uses the GitHub Search API and optional `GITHUB_TOKEN`, `GH_TOKEN`, or `gh auth token` when the GitHub CLI is already logged in.

## 数据与适用边界

Default auditing reads local files only and writes only `SOURCE.md` when requested. It does not install skills, update skills, publish packages, or contact external services unless GitHub search or a separate remote Git check is explicitly requested.

## 输出

The primary output is a short `SOURCE.md` in each skill directory. Audit mode also prints a concise table or JSON summary of detected provenance classes.

## 测试

Run the script help and a dry audit:

```bash
python scripts/manage_sources.py --help
python scripts/manage_sources.py audit --skills-root ~/.codex/skills
```

Validate the skill structure with the creator tool:

```bash
python <oil-skill-creator>/scripts/validate_skill.py <ming-skill-source-manager-path>
```
