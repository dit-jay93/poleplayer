import AppKit
import CoreVideo
import PlayerCore
import RenderCore
import Review
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root View

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDragTargeted = false
    @AppStorage("showLibrary")   private var showLibrary:   Bool = true
    @AppStorage("showInspector") private var showInspector: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Toolbar ───────────────────────────────────────────
            AppToolbar(
                showLibrary:       $showLibrary,
                showInspector:     $showInspector,
                onOpen:             appState.openPanel,
                recentURLs:         appState.recentURLs,
                onOpenRecent:       appState.open,
                onClearRecents:     appState.clearRecents,
                scopeEnabled:       $appState.scopeEnabled,
                isAnnotating:       $appState.isAnnotating,
                hasVideo:           appState.playerController.hasVideo,
                compareHasFrame:    appState.comparePixelBuffer != nil,
                compareEnabled:     $appState.compareEnabled,
                onSetCompareFrame:  appState.setCompareFrame,
                falseColorEnabled:  $appState.falseColorEnabled,
                hasPlaylist:        appState.recentURLs.count > 1,
                onPrevPlaylist:     appState.prevPlaylistItem,
                onNextPlaylist:     appState.nextPlaylistItem,
                onFullScreen:       appState.toggleFullScreen,
                onExport:           appState.exportPanel,
                gridLayout:         $appState.gridLayout,
                gridSyncEnabled:    $appState.gridSyncEnabled
            )

            // ── Work Area ─────────────────────────────────────────────
            HStack(spacing: 0) {
                if showLibrary {
                    LibraryPanel(
                        recentURLs:     appState.recentURLs,
                        currentURL:     appState.currentURL,
                        onOpen:         appState.openPanel,
                        onOpenRecent:   appState.open,
                        onClearRecents: appState.clearRecents
                    )
                    .frame(width: 240)

                    Divider().background(Theme.panelDivider)
                }

                // ── Viewer ────────────────────────────────────────────
                ZStack {
                    if appState.gridLayout != .single {
                        // 그리드 뷰어
                        GridViewerSurface(
                            slots:           appState.gridSlots,
                            layout:          appState.gridLayout,
                            activeSlotIndex: $appState.activeSlotIndex,
                            syncEnabled:     appState.gridSyncEnabled,
                            lutCube:         appState.lutCube,
                            lutEnabled:      appState.lutEnabled,
                            lutIntensity:    appState.lutIntensity,
                            onDropURL:       appState.openInSlot
                        )
                    } else {
                        // 단일 뷰어
                        ViewerSurface(
                            player:                 appState.playerController,
                            image:                  appState.currentImage,
                            lutCube:                appState.lutCube,
                            lutEnabled:             appState.lutEnabled,
                            lutIntensity:           appState.lutIntensity,
                            reviewSession:          appState.reviewSession,
                            isAnnotating:           appState.isAnnotating,
                            zoomCommand:            $appState.pendingZoomCommand,
                            scopeEnabled:           appState.scopeEnabled,
                            histogramData:          appState.histogramData,
                            onHistogram:            { appState.histogramData = $0 },
                            waveformData:           appState.waveformData,
                            onWaveform:             { appState.waveformData = $0 },
                            vectorscopeData:        appState.vectorscopeData,
                            onVectorscope:          { appState.vectorscopeData = $0 },
                            sampledPixel:           appState.sampledPixel,
                            onColorSample:          { appState.sampledPixel = $0 },
                            compareEnabled:         appState.compareEnabled,
                            comparePixelBuffer:     appState.comparePixelBuffer,
                            compareSplitX:          $appState.compareSplitX,
                            captureCompareRequest:  $appState.captureCompareRequest,
                            falseColorEnabled:      appState.falseColorEnabled,
                            videoTransform:         appState.videoTransform,
                            onTransformUpdate:      { appState.videoTransform = $0 },
                            autoToneMap:            $appState.autoToneMap,
                            onCompareCapture: { buf in
                                if let buf {
                                    appState.comparePixelBuffer = buf
                                    appState.compareEnabled = true
                                }
                            }
                        )

                        HUDOverlay(
                            player: appState.playerController,
                            image: appState.currentImage,
                            autoToneMap: $appState.autoToneMap
                        )
                        ModePill(player: appState.playerController)
                    }

                    if isDragTargeted { DropTargetOverlay() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.viewerBackground)
                .onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform: handleDrop)

                if showInspector {
                    Divider().background(Theme.panelDivider)

                    InspectorPanel(
                        isAnnotating:       $appState.isAnnotating,
                        reviewSession:      appState.reviewSession,
                        lutEnabled:         $appState.lutEnabled,
                        lutIntensity:       $appState.lutIntensity,
                        lutName:            appState.lutName,
                        libraryLUTs:        appState.libraryLUTs,
                        onOpenLUT:          appState.openLUTPanel,
                        onOpenLUTLibrary:   appState.openLUTLibraryPanel,
                        onLoadLibraryLUT:   appState.loadLibraryLUT,
                        burnInEnabled:      $appState.exportBurnInEnabled,
                        onExport:           appState.exportPanel,
                        onExportPDF:        appState.exportPDFReportPanel,
                        currentMetadata:    appState.currentMetadata,
                        exrInfo:            appState.exrInfo,
                        exrChannelMode:     $appState.exrChannelMode
                    )
                    .frame(width: 260)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Timeline Scrubber ─────────────────────────────────────
            TimelineScrubber(player: appState.activeController)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(.bar)

            // ── Transport ─────────────────────────────────────────────
            TransportBar(
                player:        appState.activeController,
                onPlayPause:   appState.gridPlayPause,
                onStop:        { appState.activeController.stop() },
                onStepBack:    { appState.activeController.stepBackward() },
                onStepForward: { appState.activeController.stepForward() },
                audioLevels:   appState.audioLevels
            )
        }
        .background(Theme.appBackground)
        .alert("Error", isPresented: $appState.isShowingError) {
            Button("OK") { appState.isShowingError = false }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
            return false
        }
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in appState.open(url: url) }
        }
        return true
    }
}

// MARK: - App Toolbar (slim, icon-based)

private struct AppToolbar: View {
    @Binding var showLibrary:   Bool
    @Binding var showInspector: Bool
    let onOpen:            () -> Void
    let recentURLs:        [URL]
    let onOpenRecent:      (URL) -> Void
    let onClearRecents:    () -> Void
    @Binding var scopeEnabled:   Bool
    @Binding var isAnnotating:   Bool
    let hasVideo:          Bool
    let compareHasFrame:   Bool
    @Binding var compareEnabled: Bool
    let onSetCompareFrame: () -> Void
    @Binding var falseColorEnabled: Bool
    let hasPlaylist:       Bool
    let onPrevPlaylist:    () -> Void
    let onNextPlaylist:    () -> Void
    let onFullScreen:      () -> Void
    let onExport:          () -> Void
    // Grid (Phase 91)
    @Binding var gridLayout:      GridLayout
    @Binding var gridSyncEnabled: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Panel toggles – left
            TBIconButton(icon: "sidebar.left",  active: showLibrary,   tip: "Library")   { showLibrary.toggle() }
            TBDivider()

            // App title
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 4)
            Text("PolePlayer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            TBDivider()

            // Media
            Button("Open…", action: onOpen)
                .buttonStyle(TBFilledButtonStyle())
                .fixedSize(horizontal: true, vertical: false)

            Menu {
                if recentURLs.isEmpty {
                    Text("No recent files").foregroundStyle(.secondary)
                } else {
                    ForEach(recentURLs, id: \.self) { url in
                        Button(url.lastPathComponent) { onOpenRecent(url) }
                    }
                    Divider()
                    Button("Clear Recents", action: onClearRecents)
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .fixedSize(horizontal: true, vertical: false)
            .help("Recent files")

            Spacer(minLength: 0)

            TBDivider()

            // View toggles
            TBIconButton(icon: "waveform.path.ecg.rectangle", active: scopeEnabled,
                         tip: "QC Scopes (H)") { scopeEnabled.toggle() }
            TBIconButton(icon: "pencil.tip", active: isAnnotating,
                         tip: "Annotate") { isAnnotating.toggle() }

            // Grid layout picker
            TBDivider()
            ForEach(GridLayout.allCases, id: \.self) { layout in
                TBIconButton(icon: layout.sfSymbol, active: gridLayout == layout,
                             tip: "Grid \(layout.rawValue)") { gridLayout = layout }
            }
            if gridLayout != .single {
                TBIconButton(icon: "arrow.triangle.2.circlepath", active: gridSyncEnabled,
                             tip: "Sync Playback") { gridSyncEnabled.toggle() }
            }

            // Compare (only when video loaded)
            if hasVideo {
                TBDivider()
                Button(action: onSetCompareFrame) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Set A Frame for compare")

                TBIconButton(icon: "rectangle.split.2x1", active: compareEnabled,
                             tip: "A/B Compare (C)") { compareEnabled.toggle() }
                    .disabled(!compareHasFrame)
                    .opacity(compareHasFrame ? 1 : 0.35)

                TBDivider()

                // False Color (V)
                TBIconButton(icon: "circle.lefthalf.filled.righthalf.striped.horizontal",
                             active: falseColorEnabled,
                             tip: "False Color (V)") { falseColorEnabled.toggle() }
            }

            // Playlist nav (when > 1 recent item)
            if hasPlaylist {
                TBDivider()
                Button(action: onPrevPlaylist) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 24, height: 28)
                }
                .buttonStyle(.plain)
                .help("Previous clip (Cmd+[)")

                Button(action: onNextPlaylist) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 24, height: 28)
                }
                .buttonStyle(.plain)
                .help("Next clip (Cmd+])")
            }

            TBDivider()

            // Full Screen
            Button(action: onFullScreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Toggle Full Screen")

            TBDivider()

            // Export
            Button(action: onExport) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .medium))
                    Text("Export")
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .buttonStyle(TBFilledButtonStyle(primary: false))
            .fixedSize(horizontal: true, vertical: false)

            TBDivider()

            // Panel toggle – right
            TBIconButton(icon: "sidebar.right", active: showInspector, tip: "Inspector") { showInspector.toggle() }
                .padding(.trailing, 4)
        }
        .frame(height: 44)
        .padding(.horizontal, 6)
        .background(.bar)
    }
}

// MARK: - Toolbar Helpers

private struct TBIconButton: View {
    let icon:   String
    let active: Bool
    let tip:    String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : Theme.secondaryText)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(active ? Color.accentColor.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tip)
    }
}

private struct TBDivider: View {
    var body: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 5)
            .opacity(0.25)
    }
}

private struct TBFilledButtonStyle: ButtonStyle {
    var primary: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(primary ? Color.accentColor : Color.white.opacity(0.09))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

// MARK: - Viewer Surface

private struct ViewerSurface: View {
    @ObservedObject var player: PlayerController
    let image: NSImage?
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double
    let reviewSession: ReviewSession?
    let isAnnotating: Bool
    @Binding var zoomCommand: ZoomCommand?
    let scopeEnabled: Bool
    let histogramData: HistogramData?
    let onHistogram: ((HistogramData) -> Void)?
    let waveformData: WaveformData?
    let onWaveform: ((WaveformData) -> Void)?
    let vectorscopeData: VectorscopeData?
    let onVectorscope: ((VectorscopeData) -> Void)?
    let sampledPixel: PixelColor?
    let onColorSample: ((PixelColor?) -> Void)?
    // A/B compare
    let compareEnabled: Bool
    let comparePixelBuffer: CVPixelBuffer?
    @Binding var compareSplitX: Float
    @Binding var captureCompareRequest: Bool
    // C: False Color
    let falseColorEnabled: Bool
    // Phase 95: 어노테이션 좌표 + HDR
    let videoTransform: VideoTransform
    let onTransformUpdate: ((VideoTransform) -> Void)?
    @Binding var autoToneMap: Bool
    let onCompareCapture: ((CVPixelBuffer?) -> Void)?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else if player.hasVideo {
                MetalVideoContainer(
                    player: player,
                    lutCube: lutCube,
                    lutEnabled: lutEnabled,
                    lutIntensity: lutIntensity,
                    reviewSession: reviewSession,
                    isAnnotating: isAnnotating,
                    zoomCommand: $zoomCommand,
                    scopeEnabled: scopeEnabled,
                    onHistogram: onHistogram,
                    onWaveform: onWaveform,
                    onVectorscope: onVectorscope,
                    onColorSample: onColorSample,
                    compareEnabled: compareEnabled,
                    comparePixelBuffer: comparePixelBuffer,
                    compareSplitX: compareSplitX,
                    captureCompareRequest: $captureCompareRequest,
                    onCompareCapture: onCompareCapture,
                    falseColorEnabled: falseColorEnabled,
                    onTransformUpdate: onTransformUpdate,
                    autoToneMap: autoToneMap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
            } else {
                PlaceholderView()
            }
        }
        .overlay {
            if let reviewSession {
                AnnotationCanvas(
                    reviewSession: reviewSession,
                    player: player,
                    isAnnotating: isAnnotating,
                    videoTransform: videoTransform
                )
            }
        }
        .overlay(alignment: .bottomLeading) {
            if scopeEnabled, let data = waveformData {
                WaveformPanel(data: data)
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if scopeEnabled {
                HStack(alignment: .bottom, spacing: 8) {
                    if let data = vectorscopeData { VectorscopePanel(data: data) }
                    if let data = histogramData   { ScopePanel(data: data) }
                }
                .padding(12)
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) {
            if let pixel = sampledPixel {
                PixelSamplerBadge(pixel: pixel)
                    .padding(.leading, 12)
                    .padding(.top, 90)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if compareEnabled, player.hasVideo {
                WipeDividerView(splitX: $compareSplitX)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(Color.white.opacity(0.12))

            VStack(spacing: 6) {
                Text("Drop a file or click Open")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                Text("ProRes · H.264 · H.265 · PNG · TIFF · EXR · DPX")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.secondaryText.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HUD Overlay

private struct HUDOverlay: View {
    @ObservedObject var player: PlayerController
    let image: NSImage?
    @Binding var autoToneMap: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HUDRow(label: "TC",    value: player.timecode)
            HUDRow(label: "Frame", value: String(player.frameIndex))
            HUDRow(label: "FPS",   value: hudFPS)
            HUDRow(label: "Res",   value: hudResolution)
            if player.hasVideo {
                HUDRow(label: "Src",    value: player.debugFrameSource)
                HUDRow(label: "PrecSrc", value: precisionSource)
                if player.hdrMode != "SDR" {
                    Button {
                        autoToneMap.toggle()
                    } label: {
                        HUDRow(label: "HDR", value: "\(player.hdrMode) \(autoToneMap ? "TM" : "RAW")")
                    }
                    .buttonStyle(.plain)
                    .help("HDR 클릭: Tone-map 토글")
                }
                if edrHeadroom > 1.01 {
                    HUDRow(label: "EDR", value: String(format: "%.1fx", edrHeadroom))
                }
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var edrHeadroom: Double {
        Double(NSScreen.main?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0)
    }

    private var hudFPS: String {
        player.fps > 0 ? String(format: "%.3f", player.fps) : "—"
    }

    private var hudResolution: String {
        if let image {
            return "\(Int(image.size.width))×\(Int(image.size.height))"
        }
        if player.resolution != .zero {
            return "\(Int(player.resolution.width))×\(Int(player.resolution.height))"
        }
        return "—"
    }

    private var precisionSource: String {
        guard player.debugLastPrecisionAt > 0 else { return "—" }
        let age = CACurrentMediaTime() - player.debugLastPrecisionAt
        return age < 2.0 ? "\(player.debugLastPrecisionSource) (recent)" : "—"
    }
}

private struct HUDRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Mode Pill

private struct ModePill: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        Text(player.mode.rawValue)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial)
            .foregroundStyle(Theme.primaryText)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(12)
    }
}

// MARK: - Drop Target Overlay

private struct DropTargetOverlay: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
            .background(Color.accentColor.opacity(0.06))
            .allowsHitTesting(false)
    }
}

// MARK: - A/B Wipe Divider

private struct WipeDividerView: View {
    @Binding var splitX: Float

    var body: some View {
        GeometryReader { geo in
            let x = CGFloat(splitX) * geo.size.width
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2)
                    .position(x: x, y: geo.size.height / 2)

                Text("A")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: max(20, x - 26), y: 22)

                Text("B")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: min(geo.size.width - 20, x + 26), y: 22)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        splitX = Float(max(0.02, min(0.98, value.location.x / geo.size.width)))
                    }
            )
        }
    }
}
