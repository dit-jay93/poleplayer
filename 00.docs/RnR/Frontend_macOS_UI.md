# RnR — Frontend (macOS UI) Engineer (SwiftUI/AppKit)
- Scope: application UI, user interactions, tool panels, and bindings to core modules

## Responsibilities
- Build app shell: library panel, viewer, inspector, transport, menus/toolbars.
- Bridge AppKit where needed (custom Metal view, advanced input handling).
- Implement command routing (keyboard shortcuts) to PlayerCore/Review.
- Implement annotation UI state and tool switching, including selection/editing.
- Implement export UI (destination, naming, options) and error messaging.

## Primary Deliverables
- UI code in `App` target
- Integration with: PlayerCore, RenderCore, Review, Export
- UI smoke tests (manual checklist)

## Codex Checklist
- [ ] Keyboard shortcuts work regardless of focus traps (viewer vs text fields)
- [ ] Tool switching is deterministic; selection/edit mode is clear
- [ ] Viewer state pill reflects actual playback mode
- [ ] Export flow is understandable and failure states are actionable
