# Development Guidelines

## Branching Strategy

| Branch | Purpose |
|--------|---------|
| `develop` | Default working branch. All feature branches are created from here. |
| `main` | Tracks upstream (`iad1tya/Net-Bar`). Only receives merges from `develop` or feature branches when preparing upstream PRs. |
| `feature/*` | Short-lived branches for individual features or fixes. Always branch off `develop`. |

### Workflow

1. Create a feature branch from `develop`:
   ```bash
   git checkout develop && git pull
   git checkout -b feature/my-feature
   ```
2. Develop and commit on the feature branch.
3. Push and open a PR targeting `develop`.
4. After merge to `develop`, changes accumulate until ready for upstream — then PR from a feature branch off `main` to `main`.

## Building

```bash
# Build only
swift build -c release

# Build + install to /Applications
bash build_and_install.sh
```

There are no tests in this project. Verify changes by building (`swift build -c release`) and manual testing.

## Commit Conventions

- Use imperative mood in the subject line (e.g. "Add red indicator" not "Added red indicator")
- Keep the subject line under 72 characters
- Use the body to explain **why**, not just what
- One logical change per commit — don't mix unrelated changes

### Commit Message Format

```
Short summary of change (imperative, <72 chars)

Optional body explaining motivation and context.
Describe what changed and why, not how.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Pull Requests

- PR title: short, under 70 characters
- PR body must include:
  - **Summary**: 1-3 bullet points describing the change
  - **Test plan**: manual verification steps
- Target `develop` for feature work (not `main`)
- One feature/fix per PR — keep PRs focused

## Code Style

- Follow existing patterns in the codebase
- Swift/SwiftUI for all UI and app logic
- C++/ObjC++ only in the `NetTrafficStat` target for low-level system calls
- Use `@AppStorage` for user-facing settings persisted in `UserDefaults`
- Use `@Published` properties on `ObservableObject` classes for reactive state
- Services that are shared across views should use the singleton pattern (`.shared`)
- Avoid adding dependencies unless absolutely necessary

## Architecture Rules

- **State layer** (`MenuBarState`, services) owns all data and logic. Views only read and bind.
- **No business logic in views** — views observe `@EnvironmentObject` / `@ObservedObject` and render.
- **1-second timer cycle** for network speed; **3-second cycle** for network stats (ping, Wi-Fi).
- All settings use `@AppStorage` with string keys — keep key names consistent (e.g. `showXxxMenu` for pin toggles).

## Adding a New Pinnable Section

1. Add the `@AppStorage` toggle to `MenuBarState` (e.g. `showFooMenu`).
2. Add the stat formatting logic in `MenuBarState.startTimer()` inside the pinned stats block.
3. Add `@AppStorage` in `StatusContentView` and use `sectionHeader("Foo", pinBinding: $showFooMenu)`.
4. Add the toggle in `SettingsView` under the appropriate "Pin to Menu Bar" group.
5. If it's a new dropdown section, also add it to `OrderManager.defaultOrder`, `visibleSections`, `isSectionEnabled`, and `sectionView(for:)`.
