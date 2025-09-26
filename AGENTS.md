# Repository Guidelines

## Project Structure & Module Organization
-  boots the Love2D game and wires core systems.
-  holds gameplay code; notable modules include  (framework utilities),  (runtime subsystems such as physics and AI),  (in-game actors), and  (HUD and panels).
-  and  store JSON/data payloads, textures, audio, and narrative content. Keep large binaries in  and lightweight config in .
- Reference the narrative and systems overviews in , , and  before adding new features.

## Build, Test, and Development Commands
-  packages the repository into ; run from the project root after verifying the workspace is clean.
-  or  launches the live game for quick iteration; ensure Love2D 11.x is installed and on PATH.
-  validates the packaged build mirrors the development run.

## Coding Style & Naming Conventions
- Lua files use 4-space indentation, snake_case locals, and PascalCase module tables (see ).
- Keep module paths rooted at  (e.g., ).
- Prefer early returns over deep nesting; annotate complex data flows with concise comments.
- Run any available formatters or lint checks you introduce with -compatible rules; include config in-repo if new tooling is added.

## Testing Guidelines
- No automated suite exists; rely on in-engine smoke tests by spawning scenarios via the debug panels in .
- When adding systems, craft reproducible test instructions in  and verify edge cases (pause/resume, state transitions, save/load).
- Document manual test steps in PR descriptions so QA can replay them.

## Commit & Pull Request Guidelines
- Follow the existing imperative, Title Case convention (, , ). Keep scope focused and reference affected subsystems in the summary.
- Squash unrelated work; include brief bullet points in the commit body for context or test notes.
- Pull requests should link tracking issues, summarize gameplay impact, and attach screenshots/GIFs for visual changes.
- Ensure checklists cover build verification () and manual playtest outcomes before requesting review.

## Security & Configuration Tips
- Store secrets outside the repo; configuration lives in  and should remain environment-agnostic.
- Validate new data files against loader expectations in  to avoid runtime crashes.
