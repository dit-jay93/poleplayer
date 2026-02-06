# STATUS

Updated: 2026-02-07 02:14 KST

Current phase: 10 — PlayerCore (M0 playback shell in progress)

What’s done
- Swift Package scaffold with modular targets (PlayerCore/DecodeKit/RenderCore/Review/Library/Export)
- Basic app shell + viewer + HUD + REAL-TIME/PRECISION pill
- AVPlayer-backed playback with JKL, space, frame step
- Pretendard fonts bundled + registered on launch
- CI workflow added (build + test)

What’s next
- Manual playback validation (ProRes/H.264/H.265 + still images)
- Tighten hybrid mode switching rules + frame-accurate step/seek validation
- Add import drag & drop and basic recent items

Blockers / Risks
- No GitHub remote configured yet (push pending)
- Precision path still uses AVPlayer seek with zero tolerance (placeholder until DecodeKit precision path)
- VFR support policy not locked yet

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Use Open… to load a MOV/MP4 or PNG/TIFF/JPG
- J/K/L for reverse/pause/forward, Space to play/pause
- Left/Right arrow or ,/. for frame step
- Verify HUD (TC/frame/FPS/res) + mode pill updates
