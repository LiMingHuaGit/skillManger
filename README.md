# Skill Manager

<p align="center">
  <img src="./assets/readme/hero.svg" width="100%" alt="Skill Manager is a macOS workbench for indexing local AI skills and copying chat-ready references.">
</p>

Skill Manager is a local-first macOS utility for people who work with reusable AI skills across Codex, Claude, ChatGPT, Cursor, and plugin-backed toolchains. It keeps the installed skill library visible, searchable, and ready to hand off into the next chat without opening Finder or memorizing paths.

## What it does

- Indexes local Codex skill roots, system skills, project skills, and plugin-provided skills.
- Shows a focused library with search, source badges, categories, health states, favorites, and recents.
- Opens a detail view with the skill description, provenance, tags, source path, duplicate information, and a useful excerpt.
- Copies platform-aware references such as Codex Markdown mentions, instruction blocks, Claude prompts, ChatGPT prompts, Cursor prompts, plain text, and custom templates.
- Provides a menu bar and notch-style workspace for quick access while staying out of the way.

## Why it exists

AI skill collections grow faster than memory. A useful skill may live under `~/.codex/skills`, inside `.system`, or in a plugin cache, and each chat surface wants a different reference format. Skill Manager turns that search-and-copy loop into a small local workflow:

```text
Index local skills -> inspect fit and health -> copy the right chat handoff
```

## Core workflow

1. Open Skill Manager from the menu bar.
2. Search by name, description, tag, platform, or source path.
3. Check the detail view for use case, provenance, health, and source excerpt.
4. Choose a target platform template.
5. Copy the generated mention or prompt and paste it into the active AI chat.

## Product surface

| Area | Purpose |
| --- | --- |
| Library | Search and filter all indexed skills, including local, system, project, and plugin entries. |
| Recommendations | Surface likely useful skills from the current Codex session context. |
| Plugins | Inspect plugin packages and their contributed skills. |
| Favorites and Recents | Keep repeat workflows close by after copy actions. |
| Settings | Manage roots, re-indexing, language, launch at login, and copy templates. |
| Notch workspace | Keep quick notes, file shelf items, and skill access near the top edge of the screen. |

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

## Build locally

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

Run tests:

```bash
xcodebuild test \
  -project skillManger.xcodeproj \
  -scheme skillManger \
  -destination 'platform=macOS'
```

Create a local DMG:

```bash
./script/package_dmg.sh
```

## Project notes

- The bundle identifier is `liminghua.skillManger`.
- The product name in the Xcode project is currently `skillManger`.
- MVP scope is intentionally focused on local library management and chat handoff, not marketplace publishing or full `SKILL.md` editing.
- The repository currently does not publish a license file.
