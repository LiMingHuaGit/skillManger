# Skill Manager MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Focused Library MVP from the PRD: local skill indexing, searchable catalog, detail preview, favorites/recents, and platform-aware copy templates.

**Architecture:** Add a small local-first SwiftUI app inside the existing file-system-synchronized Xcode project. Keep domain logic testable in pure Swift types (`Skill`, `SkillIndexer`, `CopyTemplateEngine`, `SkillLibraryStore`), then compose a native SwiftUI shell around those APIs.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing, Foundation file APIs, UserDefaults/JSON persistence, NSPasteboard for macOS clipboard.

---

### Task 1: Domain Models And Copy Templates

**Files:**
- Create: `skillManger/Models/SkillModels.swift`
- Create: `skillManger/Services/CopyTemplateEngine.swift`
- Modify: `skillMangerTests/skillMangerTests.swift`

- [x] Write failing Swift Testing coverage for skill filtering primitives and platform copy output.
- [x] Run `xcodebuild test -project skillManger.xcodeproj -scheme skillManger -destination 'platform=macOS' -only-testing:skillMangerTests` and confirm failures are missing types.
- [x] Implement value models and built-in platform templates.
- [x] Re-run the same test command and confirm the new tests pass.

### Task 2: Skill Indexing

**Files:**
- Create: `skillManger/Services/SkillIndexer.swift`
- Modify: `skillMangerTests/skillMangerTests.swift`

- [x] Write failing tests that create temporary `SKILL.md` folders and assert front matter parsing, fallback metadata, duplicate health, and unreadable/missing states.
- [x] Run the targeted tests and confirm failures.
- [x] Implement `SkillIndexer` using Foundation directory enumeration and small front matter parsing helpers.
- [x] Re-run tests and confirm passing behavior.

### Task 3: Local Store

**Files:**
- Create: `skillManger/Services/SkillLibraryStore.swift`
- Modify: `skillMangerTests/skillMangerTests.swift`

- [x] Write failing tests for favorites, recents, search, filters, default platform, and template reset/customization.
- [x] Run targeted tests and confirm failures.
- [x] Implement an observable store that loads roots, indexes skills, filters visible skills, records copy usage, and persists lightweight preferences through `UserDefaults`.
- [x] Re-run tests and confirm passing behavior.

### Task 4: SwiftUI MVP Surface

**Files:**
- Replace: `skillManger/ContentView.swift`
- Create: `skillManger/Views/SkillLibraryView.swift`
- Create: `skillManger/Views/SkillDetailView.swift`
- Create: `skillManger/Views/SettingsView.swift`
- Create: `skillManger/Views/SharedViews.swift`

- [x] Write UI-facing tests where practical through store tests first; avoid brittle snapshot tests.
- [x] Implement a `NavigationSplitView` shell with Library, Favorites, Recents, and Settings destinations.
- [x] Implement search, filter chips, rows, detail actions, copy platform picker, toast text, and settings controls.
- [x] Use `NSPasteboard` in the app layer only; keep copy string generation in tested domain code.

### Task 5: Verification And Commit

**Files:**
- All implementation files

- [x] Run `xcodebuild test -project skillManger.xcodeproj -scheme skillManger -destination 'platform=macOS'`.
- [x] Run `xcodebuild build -project skillManger.xcodeproj -scheme skillManger -destination 'platform=macOS'`.
- [x] Inspect `git status --short` and `git diff --stat`.
- [x] Commit implementation changes on `codex/skill-manager-mvp`.
