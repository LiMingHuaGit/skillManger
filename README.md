# Skill Manager

English | [简体中文](./README.zh-CN.md)

<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="Skill Manager is a notch-style macOS workspace for AI skill lookup, quick notes, and temporary file staging.">
</p>

Skill Manager is a local-first macOS utility for people who work with reusable AI skills across Codex, Claude, ChatGPT, Cursor, and plugin-backed toolchains. Its signature surface is a notch-style workspace that keeps skill lookup, quick notes, and a temporary file shelf close to the current chat without forcing you back into Finder.

## Feature tour

Four small workflows make Skill Manager useful during an AI-assisted task: find the right skill, copy the right handoff, capture temporary notes, and keep working files close to the chat.

| Focused skill library | Chat-ready skill references |
| --- | --- |
| <img src="./assets/readme/skill管理主面板.gif" width="370" alt="Skill Manager main panel showing the focused skill library and detail view."> | <img src="./assets/readme/快速引用skill.gif" width="370" alt="Skill Manager copying a skill reference for use in an AI chat."> |
| Search, filter, and inspect local, system, project, and plugin-provided skills from one workspace. | Choose a target chat format and copy the right mention or prompt for Codex, Claude, ChatGPT, Cursor, or a custom template. |

| Quick notes | File shelf |
| --- | --- |
| <img src="./assets/readme/便捷笔记.gif" width="370" alt="Skill Manager quick note panel being opened and edited with Markdown text."> | <img src="./assets/readme/文件暂存.gif" width="370" alt="Skill Manager file shelf receiving files dragged into the top workspace."> |
| Capture temporary Markdown notes near the current chat while keeping the task context visible. | Drag files into a short-lived staging surface, then keep them close to the chat or next workflow. |

## What it does

- Opens a notch-style workspace for skill management, quick notes, and a drag-friendly file staging shelf.
- Indexes local Codex skill roots, system skills, project skills, and plugin-provided skills.
- Shows a focused library with search, source badges, categories, health states, favorites, and recents.
- Opens a detail view with the skill description, provenance, tags, source path, duplicate information, and a useful excerpt.
- Copies platform-aware references such as Codex Markdown mentions, instruction blocks, Claude prompts, ChatGPT prompts, Cursor prompts, plain text, and custom templates.

## Why it exists

AI skill collections grow faster than memory, and real AI-assisted work usually also creates scratch notes and short-lived files. A useful skill may live under `~/.codex/skills`, inside `.system`, or in a plugin cache, and each chat surface wants a different reference format. Skill Manager turns that context switching into a small local workflow:

```text
Open notch workspace -> find a skill -> capture context -> stage files -> copy the handoff
```

## Highlight features

- **Notch-style skill manager:** keep the skill library one gesture away from the current task, with search, health states, categories, favorites, recents, plugin views, and platform-aware copy actions.
- **Quick note capture:** write temporary Markdown notes near the top edge of the screen while reading, coding, or chatting with an AI assistant.
- **File staging shelf:** drop files into a short-lived shelf, keep them visible while you work, then drag or copy them back into the next app or chat flow.

## Core workflow

1. Open the notch workspace or Skill Manager window from the menu bar.
2. Search by name, description, tag, platform, or source path.
3. Capture a quick note or stage related files when the task needs local context.
4. Check the skill detail view for use case, provenance, health, and source excerpt.
5. Choose a target platform template, copy the generated mention or prompt, and paste it into the active AI chat.

## Product surface

| Area | Purpose |
| --- | --- |
| Library | Search and filter all indexed skills, including local, system, project, and plugin entries. |
| Recommendations | Surface likely useful skills from the current Codex session context. |
| Plugins | Inspect plugin packages and their contributed skills. |
| Favorites and Recents | Keep repeat workflows close by after copy actions. |
| Settings | Manage roots, re-indexing, language, launch at login, and copy templates. |
| Notch workspace | Keep skill search, quick notes, and file shelf items near the top edge of the screen. |
| Quick notes | Capture Markdown scratch notes without opening a full notes app. |
| File shelf | Temporarily hold files while moving between Finder, code, and chat. |

## Copy templates

The app ships with built-in templates for common chat surfaces:

```md
[$skill_name]($skill_path)
```

```text
Use the "$skill_name" skill for this task.
Skill path: $skill_path
When to use it: $description
```

Templates are stored locally, can be edited, and can be duplicated for new platforms. Unsupported source types fall back to a generic Markdown or plain text instruction.

## Health and provenance

Skill Manager keeps routine maintenance visible without turning the app into a full editor. Indexed entries can show health states for healthy skills, missing metadata, missing files, duplicate names, and unreadable sources. Provenance records such as `SOURCE.md` are displayed when available so third-party, system, and self-created skills are easier to distinguish.

## Companion skill

Skill Manager ships with the companion skill [`$ming-skill-source-manager`](./skills/ming-skill-source-manager/SKILL.md). Use that skill to create and audit `SOURCE.md` provenance records for installed skills, then use Skill Manager to browse the results, spot third-party or unknown origins, and copy the right skill reference into chat.

Typical pairing:

```text
$ming-skill-source-manager writes SOURCE.md -> Skill Manager indexes provenance -> chat handoff includes the right skill reference
```

The bundled skill files live here:

```text
skills/ming-skill-source-manager/
├── README.md
├── SKILL.md
├── SOURCE.md
└── scripts/manage_sources.py
```

## Install

### Install the macOS app

Requirements:

- macOS with Xcode that supports the project settings.
- SwiftUI and AppKit runtime support.
- Local package dependency at `Vendor/swift-markdown-engine`.

Run the app from Xcode with the `skillManger` scheme, or build from the terminal:

```bash
xcodebuild \
  -project skillManger.xcodeproj \
  -scheme skillManger \
  -destination 'platform=macOS' \
  build
```

Create a local DMG:

```bash
./script/package_dmg.sh
```

### Install the companion skill

Manual local install:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/skills/ming-skill-source-manager"
cp -R skills/ming-skill-source-manager/. "$CODEX_HOME/skills/ming-skill-source-manager/"
python3 "$CODEX_HOME/skills/ming-skill-source-manager/scripts/manage_sources.py" --help
```

After this, invoke it in Codex as:

```md
[$ming-skill-source-manager](./skills/ming-skill-source-manager/SKILL.md)
```

If the repository is published on GitHub, it can also be installed by path with Codex's skill installer:

```bash
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo <owner>/<repo> \
  --path skills/ming-skill-source-manager
```

## Debugging

### App checks

Run tests:

```bash
xcodebuild test \
  -project skillManger.xcodeproj \
  -scheme skillManger \
  -destination 'platform=macOS'
```

When working on the notch workspace, test these flows manually after the build passes:

- Open and collapse the notch workspace from the menu bar.
- Create a quick note and confirm it remains available while switching focus.
- Drop files into the file shelf, then drag them back out.
- Search for a known skill, open its detail view, and copy a Codex mention.

### Companion skill checks

Validate the helper script:

```bash
python3 -m py_compile skills/ming-skill-source-manager/scripts/manage_sources.py
python3 skills/ming-skill-source-manager/scripts/manage_sources.py --help
```

Run a dry provenance audit without writing files:

```bash
python3 skills/ming-skill-source-manager/scripts/manage_sources.py audit --skills-root ~/.codex/skills
```

Backfill missing `SOURCE.md` files only when you intend to write changes:

```bash
python3 skills/ming-skill-source-manager/scripts/manage_sources.py audit \
  --skills-root ~/.codex/skills \
  --include-system \
  --write \
  --write-unknown
```

Use GitHub search only when you explicitly want network lookup for unresolved unknown skills:

```bash
python3 skills/ming-skill-source-manager/scripts/manage_sources.py audit \
  --skills-root ~/.codex/skills \
  --include-system \
  --github-search-unknown
```

Do not write tokens, secrets, or credential-bearing clone URLs into `SOURCE.md`.

## Project notes

- The bundle identifier is `com.example.skillManger`.
- The product name in the Xcode project is currently `skillManger`.
- MVP scope is intentionally focused on local library management and chat handoff, not marketplace publishing or full `SKILL.md` editing.
- The repository currently does not publish a license file.
