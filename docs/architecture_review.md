# Architecture Review

## Current Structure
- `main.lua` bootstraps core services and uses `ModuleRegistry` for a handful of lazily loaded screens and managers. 【F:main.lua†L19-L27】
- `ModuleRegistry` wraps lazy loaders, caching modules once required and allowing manual cache invalidation. 【F:src/core/module_registry.lua†L18-L79】
- Subsystems such as the UI manager and input layer require each other directly and maintain feature-specific state tables. 【F:src/core/ui_manager.lua†L15-L189】【F:src/core/input.lua†L5-L200】

## Areas That Limit Modularity
1. **Partial use of the registry** – Only top-level screens are routed through `ModuleRegistry`. Deeper systems still require one another directly, so adding a new UI or gameplay system usually means editing multiple files. 【F:main.lua†L19-L27】【F:src/core/ui_manager.lua†L15-L189】
2. **UIManager as a central choke point** – `src/core/ui_manager.lua` hard-codes every panel (cargo, ship, warp, etc.) and even creates fallback shims. To introduce a new panel you must edit this file, wire z-order defaults, and possibly extend fallback logic, which contradicts the goal of pluggable UI modules. 【F:src/core/ui_manager.lua†L15-L189】
3. **Input module knows about UI implementation details** – `src/core/input.lua` pulls in specific UI panels and systems to query visibility or dispatch events. That couples gameplay input to UI internals and makes it difficult to swap panels or reuse the input layer in other contexts. 【F:src/core/input.lua†L5-L200】

## Recommendations
- **Standardize dependency injection** – Expand `ModuleRegistry` (or a similar registry) so that feature modules register themselves by key and consumers resolve them through the registry instead of `require`. That keeps `main.lua`, the UI manager, and the input layer agnostic to concrete implementations and avoids editing central files for new features. 【F:main.lua†L19-L27】【F:src/core/module_registry.lua†L18-L79】
- **Make UI components self-registering** – Have each panel call into `Registry` (or another dispatcher) during its `init` and provide metadata such as default z-index and modal behavior. The UI manager can iterate over registered panels rather than hard-coding tables of names. This also removes the need for fallback stubs when a module fails to load. 【F:src/core/ui_manager.lua†L15-L189】【F:src/ui/core/registry.lua†L1-L42】
- **Decouple input handling from UI specifics** – Move UI-specific checks (cargo search boxes, docking screens) behind small interfaces that the UI layer exposes. The input system should query a high-level capability like `UIManager:isTextInputCaptured()` instead of reaching into concrete panels. That keeps gameplay input modular and easier to extend. 【F:src/core/input.lua†L64-L86】

Implementing these changes incrementally will preserve the existing simplicity while giving you a clearer extension surface for future modules.

## Follow-Up Progress
- Introduced metadata-aware module registration so callers can resolve modules by tag and access declarative attributes (default z-index, modal state, etc.) without touching central bootstrap files. 【F:src/core/module_registry.lua†L1-L132】
- Added a discovery-driven UI panel registry that loads panel descriptors from `src/ui/panels/registry`, registers them with the module registry, and exposes capture hooks for text input checks. 【F:src/ui/core/panel_registry.lua†L1-L120】【F:src/ui/panels/init.lua†L1-L42】
- Updated `UIManager` and the input pipeline to consume the registry, letting new panels plug in by dropping a registration file instead of editing `UIManager` directly. 【F:src/core/ui_manager.lua†L1-L884】【F:src/core/input.lua†L1-L120】
