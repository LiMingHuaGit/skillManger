# Skill Manager Focused Library PRD

Date: 2026-07-14
Status: Draft for review
Owner: Ming
Target platform: iOS SwiftUI app

## 1. Product Summary

Skill Manager is a local-first utility for people who use AI chat tools with reusable AI skills. The first release focuses on one high-frequency job: help the user quickly find a locally installed skill, understand when to use it, and copy a platform-appropriate reference into Codex, Claude, or another AI chat surface.

The MVP is a focused library, not a full skill IDE. It indexes local skill folders and plugin-provided skill manifests, presents a searchable catalog, shows a concise detail view, and provides one-tap copy actions for platform-specific mention or prompt templates.

## 2. Problem

AI skill collections grow quickly across local custom skills, plugin skills, and project instructions. During a chat, the user often has to remember the exact skill name, path, plugin source, and right invocation style. That breaks flow: the user leaves the chat, searches the filesystem, opens `SKILL.md`, copies a path or mention, and returns to the conversation.

The product should reduce that context switch to a short loop: open Skill Manager, search, tap copy, paste into chat.

## 3. Goals

- Make locally available AI skills visible as a clean, searchable library.
- Help the user decide whether a skill is relevant without reading the full `SKILL.md`.
- Copy the right reference format for the target chat platform.
- Remember favorites and recently used skills so repeated workflows get faster.
- Surface basic health signals such as missing file, unreadable manifest, duplicate name, or stale index.

## 4. Non-Goals For MVP

- No full `SKILL.md` editor.
- No installing, updating, deleting, or publishing skills.
- No automatic recommendation from live chat content.
- No deep integration with Codex, Claude, Cursor, or browser extension APIs.
- No cloud sync or account system.
- No team sharing or marketplace.

## 5. Primary Users

- Power users who maintain custom skills under `~/.codex/skills` or similar local directories.
- Developers and designers who invoke plugin skills during AI-assisted work.
- Users who switch between Codex, Claude, and other chat tools and need different reference formats.

## 6. Core User Stories

- As a user, I want to see all local skills in one searchable list so I do not need to inspect folders manually.
- As a user, I want to read a short description, trigger rules, and source path for a skill so I know whether it fits my current chat.
- As a Codex user, I want to copy a Codex-compatible skill mention or Markdown link so I can paste it into the current task.
- As a Claude user, I want to copy a Claude-friendly instruction phrase so I can invoke the same skill concept in Claude without hand rewriting.
- As a user, I want platform templates to be editable or configurable so new AI chat tools can be added without app updates.
- As a frequent user, I want favorites and recent skills so recurring workflows are one tap away.

## 7. MVP Scope

### 7.1 Skill Indexing

The app indexes local skill sources from configurable roots. Default roots:

- `~/.codex/skills`
- `~/.codex/skills/.system`
- Optional plugin cache roots discovered from local Codex metadata when available

For each skill, parse:

- Skill name
- Description
- Source type: local, system, plugin, project
- Absolute `SKILL.md` path or plugin URI
- Root folder
- Tags inferred from path, plugin prefix, and description keywords
- Last modified date
- Health status

Health states:

- Healthy: readable `SKILL.md` with name and description
- Missing metadata: readable file but incomplete front matter
- Missing file: index entry points to a removed file
- Duplicate name: same visible name appears in multiple sources
- Unreadable: permission or parse failure

### 7.2 Library Screen

The first screen is the working surface.

Required elements:

- Search field for name, description, tag, platform, and source path
- Filter chips: All, Favorites, Recent, Local, Plugin, Needs Review
- Skill list rows with name, source badge, short description, favorite state, and health indicator
- Sort options: relevance, recently used, recently modified, name
- Empty states for no skills, no search result, and inaccessible roots

### 7.3 Skill Detail

Selecting a skill opens a detail surface.

Required content:

- Skill name and description
- Use-when summary extracted from description and first lines of `SKILL.md`
- Source path or plugin URI
- Root/source type
- Last indexed time and health state
- Tags
- Preview of the relevant `SKILL.md` excerpt, with full file opening deferred to a later release

Required actions:

- Copy mention/reference
- Copy full prompt snippet
- Favorite/unfavorite
- Reveal source path in share sheet or clipboard
- Re-index this skill

### 7.4 Platform-Aware Copy

Copy is the most important MVP interaction. The user chooses a target platform before copying, and the app produces the correct template for that platform.

Built-in platform targets:

- Codex
- Claude
- ChatGPT
- Cursor
- Generic Markdown
- Plain text instruction
- Custom platform template

Recommended default templates:

Codex local skill:

```md
[$skill_name]($skill_path)
```

Codex plugin skill:

```md
[@$plugin_name](plugin://$plugin_id)
```

Codex instruction block:

```md
在需要处理「$use_case」时，配合 skill：[$skill_name]($skill_path)
```

Claude instruction:

```text
Use the "$skill_name" skill for this task.
Skill path: $skill_path
When to use it: $description
```

ChatGPT instruction:

```text
Please use the following skill guidance for this task:
Skill: $skill_name
When to use it: $description
Source: $skill_path
```

Cursor instruction:

```text
Use this skill context while working in the codebase:
$skill_name - $description
Source: $skill_path
```

Generic Markdown:

```md
**Skill:** [$skill_name]($skill_path)
**Use when:** $description
```

Plain text:

```text
Skill: $skill_name
Path: $skill_path
Use when: $description
```

Template requirements:

- Templates are stored locally and can be edited in settings.
- The app validates required variables before copy.
- Unsupported source types fall back to Generic Markdown.
- The last used platform becomes the default for the next copy.
- Platform support is copy-template support in MVP, not direct API integration with the target chat app.
- Users can create custom platform templates by duplicating a built-in template and editing its variables.

### 7.5 Favorites And Recents

- Favorite/unfavorite a skill from list row or detail view.
- Recent skills update after any copy action.
- Favorites and recents are stored locally.
- Recents include platform copied, timestamp, and copy template type.

### 7.6 Settings

MVP settings are intentionally small:

- Skill roots: add, remove, enable, disable local folders
- Re-index now
- Default platform target
- Edit copy templates
- Reset templates to defaults
- Add custom platform template
- Show hidden/system/plugin skills toggle

## 8. Interaction Model

### Primary Flow

1. User opens Skill Manager while chatting with an AI tool.
2. User searches or opens Favorites/Recent.
3. User selects a skill.
4. Detail view explains when to use it and shows source health.
5. User chooses a platform target if needed.
6. User taps Copy mention or Copy prompt.
7. App copies the generated text, records recent usage, and shows a confirmation toast.
8. User returns to the AI chat and pastes.

### Secondary Flow: Review Skill Health

1. User filters by Needs Review.
2. User selects a skill with missing metadata or duplicate name.
3. App explains the issue and shows source path.
4. User copies path or re-indexes after making local changes outside the app.

### Secondary Flow: Configure A New Platform

1. User opens Settings > Copy Templates.
2. User duplicates an existing template.
3. User names the platform and edits variables.
4. App previews sample output using a real skill.
5. User saves and can use the platform in the copy menu.

## 9. Information Architecture

Top-level tabs or navigation destinations:

- Library: default working surface
- Favorites: saved skills, also reachable as a filter in Library
- Recents: recently copied skills, also reachable as a filter in Library
- Settings: roots, indexing, platform templates

On compact iPhone layouts, use a tab bar. On iPad or larger layouts, use a sidebar with Library, Favorites, Recents, and Settings.

## 10. UI Style Direction

The app should feel like a focused local utility for serious AI work: quiet, fast, and readable.

Visual principles:

- Use a mostly black-and-white editorial base with subtle hairline dividers.
- Use restrained pastel accents from the existing `DESIGN-figma.md` direction to mark source types or states, not as decorative hero panels.
- Prefer dense but comfortable lists over marketing-style cards.
- Keep cards to real grouped objects such as skill detail panels; avoid nested cards.
- Use 8px radius for list rows, inputs, and small panels.
- Use pill controls for filters and platform selection.
- Use native SF symbols for actions such as search, favorite, copy, refresh, warning, and settings.
- Use system typography or Inter-like hierarchy: readable 14-17pt body sizes, clear 20-24pt detail titles, mono only for paths and copied snippets.

Color guidance:

- Base canvas: white
- Ink: black
- Soft surface: off-white
- Hairline: light gray
- Source accents: lilac for plugin, lime for local, coral for system, mint for project
- Warning/needs review: system yellow or a restrained amber label

## 11. Data Model

Core entities:

- `Skill`: id, name, description, sourceType, sourcePath, pluginURI, rootPath, tags, lastModifiedAt, lastIndexedAt, healthStatus
- `SkillRoot`: id, path, enabled, sourceType, lastIndexedAt, lastError
- `PlatformTemplate`: id, platformName, templateType, body, isBuiltIn, isDefault
- `UsageEvent`: id, skillId, platformTemplateId, copiedAt, copyType
- `UserPreference`: defaultPlatformId, showSystemSkills, showPluginSkills, sortMode

Persist MVP data locally with SwiftData or a small local JSON store. The implementation choice can be finalized during engineering planning.

## 12. Indexing And Parsing Requirements

- Indexing should run on first launch, manual refresh, and app foreground when roots changed.
- Parsing should prefer structured front matter when present.
- If front matter is missing, infer a display name from folder/file name and use the first meaningful paragraph as description.
- Indexing failures should not block the whole library.
- The UI should show partial results while indexing continues.
- Duplicate names should remain visible with source badges and paths to disambiguate.

## 13. Accessibility And Localization

- All primary actions must have accessible labels.
- Copy buttons must announce success.
- Color cannot be the only health/source indicator; include text or icon labels.
- Dynamic Type should be supported for list rows and detail content.
- MVP copy around settings and labels should support Chinese UI first, with English skill names preserved.

## 14. Success Metrics

- User can find a known skill in under 10 seconds.
- User can copy a platform-specific reference in two taps after selecting a skill.
- Indexing a normal local skill folder completes without blocking the UI.
- Favorites and recents reduce repeat copy actions to one or two taps.
- The user does not need to open Finder or manually inspect `SKILL.md` for routine skill invocation.

## 15. Acceptance Criteria

- On first launch, the app can index configured local roots and show a populated library when skills exist.
- Search returns matching skills by name, description, tag, and path.
- A skill detail view shows name, description, source, health, tags, and a source excerpt.
- Copy mention works for Codex local skill, Codex plugin skill, Claude instruction, ChatGPT instruction, Cursor instruction, Generic Markdown, and Plain Text.
- Platform templates can be edited and reset.
- A custom platform template can be created from a built-in template and used from the copy menu.
- Favorites and recents persist after app relaunch.
- Health filter shows skills with missing metadata, duplicate names, missing files, or unreadable state.
- Empty and error states are understandable and actionable.

## 16. Future Phases

Phase 2: Skill Sets

- Create reusable groups such as iOS Build Kit or Product Design Kit.
- Copy multiple skill references as one workflow prompt.
- Pin sets to the library home.

Phase 3: Chat Companion

- Suggest skills from pasted task text.
- Generate a platform-specific prompt recipe from selected skills.
- Optionally integrate with a share extension or floating utility.

Phase 4: Skill Maintenance

- Edit `SKILL.md` safely.
- Validate skill format.
- Install, update, remove, and back up skills.
- Compare duplicate or conflicting skills.

## 17. Open Decisions For Engineering Plan

- Whether MVP persistence should use SwiftData or JSON files.
- Whether plugin skill discovery should parse Codex metadata directly or accept user-configured plugin cache roots first.
- Exact Codex plugin URI mapping for plugin-contributed skills, since local plugin cache paths may not always expose a stable public plugin URI.
- Whether the first iOS build needs iCloud backup disabled for local index data.
