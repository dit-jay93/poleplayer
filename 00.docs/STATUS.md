# STATUS

Updated: 2026-02-22 KST (Phase 95)

Current phase: 95 — Playback Stabilization & Bug Fixes (complete)

What's done
- Swift Package scaffold with modular targets (PlayerCore/DecodeKit/RenderCore/Review/Library/Export)
- Basic app shell + viewer + HUD + REAL-TIME/PRECISION pill
- AVPlayer-backed playback with JKL, space, frame step
- Pretendard fonts bundled + registered on launch
- CI workflow added (build + test)
- Headless AVFoundation smoke decode on TestClips (load + frame extract OK)
- Viewer rendering path switched to Metal (MTKView)
- AssetReader decode path added for Metal rendering (AVAssetReaderTrackOutput → CVPixelBuffer)
- Debug pattern (checkerboard) + frame counters + render ticks added
- SwiftUI views now observe PlayerController directly so state changes render
- Precision path uses AVAssetImageGenerator to render frozen frame on seek/step
- HUD now distinguishes frozen precision frames: `Src` shows `imageGen` when frozen; `PrecSrc` shows imageGen or imageGen-fail (recent)
- Timeline state machine added (stopped/paused/playing) with in/out points and loop control
- Hybrid mode switching centralized for precision triggers (step/seek/annotate/export)
- DecodeKit precision path wired into PlayerCore (AVFoundationDecoder)
- Decoder prefetch warm-up implemented (best-effort)
- Unsupported codec detection now surfaces an error message
- LUT pipeline: .cube parser + Metal 3D LUT upload + intensity blend
- LUT UI: Open LUT panel + Toggle (T) + intensity slider
- RenderCore HUD overlay (TC/frame/FPS/res) composited in Metal
- RenderCore burn-in renderer helper added for export path
- ReviewStore (SQLite) added with assets/review_items/annotations tables
- Review models include normalized geometry types; ReviewStore round-trip tests pass
- Annotation toolset UI added (pen/rect/circle/arrow/text)
- ReviewSession wired to asset hashing; review state loads on open and overlays render in Metal
- Export pipeline: clean still always written; burn-in (still + overlay composited) written only when overlay present
- Export UI: Burn-in toggle + Export… panel (choose folder) + naming template
- notes.json includes asset hash + timeline metadata + annotations
- Bench CLI: step accuracy + random seek + LUT toggle harness with JSON report
- CI: reduced bench run (auto-generated clip) added
- Annotation editing: select/move/delete + text edit UI + selection outline
- Drag & drop file open (video + image)
- Recent items (up to 10, persisted in UserDefaults, menu in TopBar)
- Audio: volume slider + mute toggle (M key); AVPlayer volume/mute wired
- Frame step repeat-hold: step keys repeat, all other shortcuts single-fire
- Still image folder navigation: open any image → ← → / ,. step through siblings
- Review notes/tags UI: Info… popover with title + comma-separated tags, persisted to ReviewStore
- Zoom/pan: pinch + scroll wheel + drag; double-click to reset
- Zoom shortcuts: F = fit, G = fill (no black bars, crops), 1 = 1:1 pixel
- LUT library folder: Set Library Folder… scans for .cube files, persisted across launches; LUT menu lists all for quick switch
- Keyboard shortcuts: app-level NSEvent monitor — shortcuts work regardless of focused control; suppressed only when text field is active
- QC Scopes (H key): RGB histogram + vectorscope (bottom-right HStack) + luma waveform (bottom-left); all ≤10 fps shared throttle
- Pixel sampler: hover over video → live RGB + hex badge (top-left below HUD); disabled when annotating
- EXR support: macOS ImageIO + Core Image fallback; drag & drop and Open panel (UTType registered)
- DPX support: custom 10-bit RGB decoder in DecodeKit; Cineon log → gamma 2.2 LUT; big/little-endian; folder navigation included
- Precision frame cache: FrameCache (capacity=8, NSLock, FIFO eviction) in PlayerCore; cache hit fast-path in generateFrozenFrame; HUD Src shows "cache" on hit
- Precision prefetch: scheduleFramePrefetch(around:) dispatches ±2 frame background decodes on imageGenQueue after each step/seek; evicts beyond ±4 window
- A/B wipe compare: Metal shader wipe (left=A frame, right=B frame, both see LUT); "Set A" button + draggable WipeDivider overlay; C key toggles; compare resets on new file open
- UI redesign: 3-panel layout (Library 240px | Viewer | Inspector 260px); slim icon toolbar (44pt, SF Symbols, no text wrapping); LibraryPanel (recent files); InspectorPanel (Tools + LUT + Notes + Export); @AppStorage panel persistence
- Liquid Glass: NSVisualEffectView — toolbar .headerView, panels .sidebar, transport .titlebar; HUD rows .ultraThinMaterial; ModePill .thinMaterial
- Plugin Decoder Architecture: DecoderRegistry (등록/자동선택), DecoderPlugin: Sendable, setFPSHint 기본구현; ARRIRawDecoder + RedDecoder 스텁 (SDK 미설치 안내); PlayerController가 registry 사용; AppState에 .ari/.arx/.r3d 확장자 추가
- EXR Multi-channel AOV: EXRInspector (순수 Swift 헤더 파서, OpenEXR magic 검증, chlist 파싱, 레이어 그룹핑); EXRChannelProcessor (CIColorMatrix — R/G/B/A/Y 채널 격리); AppState exrInfo/exrChannelMode/$exrChannelMode Combine 구독; InspectorPanel EXRChannelSection (채널 버튼 + 레이어별 채널 목록 + 픽셀타입 표시)
- Multi-clip Grid Viewer: GridLayout (1×1/1×2/2×2), GridSlot (@MainActor, 독립 PlayerController), GridViewerSurface (LazyVGrid, 드래그&드롭, 활성 셀 테두리, 파일명 레이블); AppState gridLayout/gridSlots/activeSlotIndex/gridSyncEnabled/activeController; 툴바 그리드 버튼 + Sync 토글; JKL/스페이스 sync-all 지원; TransportBar/TimelineScrubber activeController 연결
- PDF Report Export: PDFReportBuilder (CoreGraphics CGPDFContext, A4, 상단 플립 좌표계); 헤더(다크/액센트 스트라이프/파일명/TC/FPS/저자/날짜), 스틸 이미지(baseImage+overlayImage 합성), 어노테이션 표(인덱스/TC/타입/텍스트, 교차 행 음영), Notes/Tags 섹션, 푸터(앱버전/날짜/SHA256 해시); 어노테이션 오버플로우 시 2페이지 자동 분할; InspectorPanel "PDF Report…" 버튼; AppState exportPDFReportPanel()
- HDR / Wide Gamut: MTKView 픽셀 포맷 .rgba16Float; CAMetalLayer wantsExtendedDynamicRangeContent + extendedSRGB 컬러스페이스; MetalRenderer 파이프라인 .rgba16Float; PlayerController hdrMode (HLG/HDR10/Linear/SDR) — CMFormatDescriptionGetExtension 전송 함수 감지; HUD HDR/EDR 행 (SDR가 아닐 때 / headroom > 1.01x)
- Timeline Thumbnail Strip: PlayerController.generateThumbnails() — background Task + AVAssetImageGenerator (160×90, tolerance 0.5s), 20개 점진 업데이트; thumbnailTask 취소 on clear(); TimelineScrubber ThumbnailStrip — GeometryReader HStack + scaledToFill + RoundedRectangle 클립, allowsHitTesting(false)

QA 수정 (complete)
- [x] 재생 버그: audioMeter.attach가 replaceCurrentItem 전에 await → 비블로킹 Task로 변경, clear()에 detach 추가
- [x] AudioMeterMonitor: retain-before-check 누수 수정, OSAllocatedUnfairLock으로 peak 경쟁 상태 방지
- [x] AppState: deinit으로 key event monitor 해제 (nonisolated(unsafe) 적용)
- [x] AppState: scanLibraryFolder 백그라운드 Task.detached로 비블로킹
- [x] AppState: openImage extractImage 비블로킹 (Task.detached + await)
- [x] MetalVideoContainer: captureCompareRequest 중복 캡처 방지
- [x] MetalVideoView: OSAllocatedUnfairLock으로 userScale/userOffset 렌더 스레드 안전

V2 Features (complete)
- [x] A: Timeline scrubber — 클릭/드래그 시크, In/Out 마커, 루프구간 강조, 플레이헤드
- [x] B: 파일 메타데이터 패널 — Inspector 상단 MediaInfo 섹션 (코덱/비트레이트/해상도/FPS/색공간/HDR/오디오)
- [x] C: False Color 오버레이 — Metal shader 8존 luma-to-color 매핑, V 키 토글, 툴바 버튼
- [x] D: 멀티클립 플레이리스트 — recentURLs 기반, Cmd+[/] 이전/다음 클립, 툴바 nav 버튼
- [x] E: 오디오 미터 — MTAudioProcessingTap + vDSP_measqv, L/R RMS + 피크홀드, AudioMeterView (TransportBar 내)
- [x] F: 전체화면 모드 — NSWindow.toggleFullScreen, 툴바 버튼

What's next (validation)
- Manual GUI playback validation (ProRes / H.264 / H.265 + still images)
- Precision frame accuracy spot-check on ProRes (random frames, target ±0 frames)
- Confirm relaunch restore flow with a reference clip (annotations + notes + tags)
- Export package cross-machine check (notes.json reproduces annotations)
- Benchmark pass/fail review against BENCHMARK.md criteria

Blockers / Risks
- Audio/video sync may drift (AssetReader frames are timer-driven)
- VFR support policy not locked yet
- Timecode track parsing deferred (timecode display is fps-derived)

What Jay can test right now
- Open `Package.swift` in Xcode and run `PolePlayerApp`
- Drag & drop a video or image file onto the viewer
- J/K/L for reverse/pause/forward, Space to play/pause (works after any button click)
- Left/Right arrow or ,/. for frame step; hold to repeat
- I = set In point, O = set Out point, U = clear In/Out, P = toggle Loop
- M = mute/unmute; volume slider in transport bar
- T = LUT toggle; load a .cube via LUT… → Open LUT File…
- Set a LUT library folder via LUT… → Set Library Folder…, then select LUTs from the list
- F = fit zoom, G = fill zoom, 1 = 1:1 pixel; scroll/pinch to zoom, drag to pan, double-click to reset
- Open an image → use ← → to step through images in the same folder
- Toggle Annotate → draw pen/rect/circle/arrow/text; relaunch to confirm restore
- Info… popover to set review title and tags
- Select annotation → move/delete; text annotation → edit inline
- H = toggle QC Scopes; waveform (bottom-left) + vectorscope + histogram (bottom-right) appear over video
- Open or drag & drop EXR / DPX files; ← → navigates siblings in same folder
- Hover cursor over video → live pixel RGB + hex badge appears (top-left below HUD)
- A/B compare: click "Set A" to capture current frame, toggle "Compare" (or C key); drag the white divider line left/right to adjust wipe split
- Toggle Burn-in, click Export…, choose a folder
  - Package contains: clean still PNG + (if overlay) burnin PNG + notes.json
- Run bench: `swift run PolePlayerBench --input /path/to/clip.mov --output /path/to/output`
