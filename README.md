# PolePlayer

High-end macOS GPU-accelerated video/image player (MVP in progress).

## Build & Run (macOS)
- Open `Package.swift` in Xcode and run the `PolePlayerApp` scheme.
- Or via CLI:
  - `swift build`
  - `swift run PolePlayerApp`

## Notes
- Pretendard fonts are bundled under `Sources/PolePlayerApp/Resources/Fonts/` and registered at launch.
- Module targets are scaffolded for PlayerCore, DecodeKit, RenderCore, Review, Library, Export.
