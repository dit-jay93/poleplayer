import AppKit
import Combine
import CoreImage
import Foundation
import UniformTypeIdentifiers
import simd
import os
import DecodeKit
import PlayerCore
import RenderCore
import Review
import Export

// MARK: - VideoTransform

struct VideoTransform: Equatable {
    var scale: SIMD2<Float> = SIMD2(1, 1)
    var offset: SIMD2<Float> = SIMD2(0, 0)
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentImage: NSImage? = nil
    @Published var currentURL: URL? = nil
    @Published var errorMessage: String? = nil
    @Published var isShowingError: Bool = false
    @Published var lutCube: LUTCube? = nil
    @Published var lutEnabled: Bool = false
    @Published var lutIntensity: Double = 1.0
    @Published var lutName: String? = nil
    @Published var isAnnotating: Bool = false
    @Published var exportBurnInEnabled: Bool = false
    @Published private(set) var recentURLs: [URL] = []
    @Published var pendingZoomCommand: ZoomCommand? = nil
    @Published private(set) var libraryLUTs: [URL] = []
    @Published var scopeEnabled: Bool = false
    @Published var histogramData: HistogramData? = nil
    @Published var waveformData: WaveformData? = nil
    @Published var vectorscopeData: VectorscopeData? = nil
    @Published var sampledPixel: PixelColor? = nil
    // A/B compare
    @Published var compareEnabled: Bool = false
    @Published var comparePixelBuffer: CVPixelBuffer? = nil
    @Published var compareSplitX: Float = 0.5
    @Published var captureCompareRequest: Bool = false
    // B: 메타데이터
    @Published var currentMetadata: MediaMetadata = .empty
    // C: False Color
    @Published var falseColorEnabled: Bool = false
    // D: 플레이리스트 (recentURLs 기반, 현재 위치 추적)
    @Published private(set) var playlistIndex: Int = -1
    // E: 오디오 레벨
    @Published var audioLevels: AudioMeterMonitor.Levels = .silent
    // EXR 멀티채널 (Phase 90)
    @Published private(set) var exrInfo: EXRInfo? = nil
    @Published var exrChannelMode: EXRChannelMode = .composite
    // Phase 95: 어노테이션 좌표 역변환용 Metal 뷰 transform
    // @Published 대신 수동 퍼블리시 — 값이 같으면 SwiftUI 재렌더 루프 방지
    private var _videoTransform: VideoTransform = VideoTransform()
    var videoTransform: VideoTransform {
        get { _videoTransform }
        set {
            guard newValue != _videoTransform else { return }
            objectWillChange.send()
            _videoTransform = newValue
        }
    }
    // Phase 95: HDR → SDR 자동 톤맵
    @Published var autoToneMap: Bool = false

    // Grid (Phase 91)
    @Published var gridLayout: GridLayout = .single {
        didSet { if oldValue != gridLayout { updateGridSlots() } }
    }
    @Published private(set) var gridSlots: [GridSlot] = []
    @Published var activeSlotIndex: Int = 0
    @Published var gridSyncEnabled: Bool = true

    let reviewSession: ReviewSession?

    private static let recentURLsKey = "recentItems"
    private static let maxRecentCount = 10
    private static let libraryFolderKey = "lutLibraryFolder"

    // Still image folder navigation
    private var folderImages: [URL] = []
    private var folderImageIndex: Int = 0

    // EXR 채널 처리용 원본 이미지
    private var exrBaseImage: NSImage? = nil

    let playerController = PlayerController()

    /// 현재 활성 PlayerController — 단일 모드에서는 playerController, 그리드 모드에서는 활성 슬롯의 controller.
    var activeController: PlayerController {
        guard gridLayout != .single, activeSlotIndex < gridSlots.count else { return playerController }
        return gridSlots[activeSlotIndex].controller
    }

    private let log = Logger(subsystem: "PolePlayer", category: "AppState")
    private var cancellables: Set<AnyCancellable> = []
    private let reviewStore: ReviewStore?
    // nonisolated(unsafe): deinit에서 안전하게 접근하기 위해 필요
    nonisolated(unsafe) private var keyEventMonitor: Any?

    private let videoExtensions = ["mov", "mp4", "m4v", "ari", "arx", "r3d"]
    private let imageExtensions = ["png", "jpg", "jpeg", "tif", "tiff", "exr", "dpx"]

    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    init() {
        if let store = AppState.makeReviewStore() {
            self.reviewStore = store
            self.reviewSession = ReviewSession(store: store)
        } else {
            self.reviewStore = nil
            self.reviewSession = nil
        }
        recentURLs = AppState.loadRecentURLs()
        if let path = UserDefaults.standard.string(forKey: Self.libraryFolderKey) {
            scanLibraryFolder(URL(fileURLWithPath: path))
        }
        playerController.$lastErrorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.showError(message)
            }
            .store(in: &cancellables)

        // E: 오디오 레벨 구독
        playerController.audioMeter.onLevels = { [weak self] levels in
            DispatchQueue.main.async {
                self?.audioLevels = levels
            }
        }

        // EXR 채널 모드 변경 시 이미지 재처리
        $exrChannelMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.applyEXRChannel(mode: mode)
            }
            .store(in: &cancellables)

        // HDR 영상 감지 시 autoToneMap 자동 활성화/비활성화
        playerController.$hdrMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.autoToneMap = (mode != "SDR")
            }
            .store(in: &cancellables)

        // Install app-level key monitor so shortcuts work regardless of focused control.
        // Returns nil (consuming the event) unless a text field is active or Command is held.
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.modifierFlags.contains(.command) { return event }
            if let responder = NSApp.keyWindow?.firstResponder,
               responder.isKind(of: NSText.self) { return event }
            MainActor.assumeIsolated { self.handleKeyDown(event: event) }
            return nil
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        var types: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .png, .tiff, .jpeg]
        if let exrType = UTType("com.ilm.openexr-image") { types.append(exrType) }
        if let dpxType = UTType(filenameExtension: "dpx") { types.append(dpxType) }
        panel.allowedContentTypes = types
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.open(url: url)
        }
    }

    func openLUTPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let lutType = UTType(filenameExtension: "cube") ?? .data
        panel.allowedContentTypes = [lutType]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openLUT(url: url)
        }
    }

    func openLUTLibraryPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Set as LUT Library"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            UserDefaults.standard.set(url.path, forKey: Self.libraryFolderKey)
            self?.scanLibraryFolder(url)
            self?.log.info("LUT library folder set: \(url.lastPathComponent, privacy: .public)")
        }
    }

    func loadLibraryLUT(url: URL) {
        openLUT(url: url)
    }

    private func scanLibraryFolder(_ url: URL) {
        Task.detached(priority: .utility) { [weak self, url] in
            let files = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )) ?? []
            let luts = files
                .filter { $0.pathExtension.lowercased() == "cube" }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            await MainActor.run { [weak self] in
                self?.libraryLUTs = luts
                self?.log.info("LUT library scanned: \(luts.count, privacy: .public) LUTs")
            }
        }
    }

    func open(url: URL) {
        let ext = url.pathExtension.lowercased()

        // 그리드 모드: 활성 슬롯에 비디오만 허용
        if gridLayout != .single {
            if videoExtensions.contains(ext) {
                openInSlot(activeSlotIndex, url: url)
            } else {
                showError("Grid mode supports video files only.")
            }
            return
        }

        currentURL = url
        if imageExtensions.contains(ext) {
            addRecent(url)
            openImage(url: url)
            return
        }
        if videoExtensions.contains(ext) {
            addRecent(url)
            openVideo(url: url)
            return
        }
        showError("Unsupported file type: .\(ext)")
    }

    func clearRecents() {
        recentURLs = []
        UserDefaults.standard.removeObject(forKey: Self.recentURLsKey)
    }

    func exportPanel() {
        guard currentURL != nil else {
            showError("Load a media file before exporting.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { [weak self] in
                await self?.exportPackage(to: url)
            }
        }
    }

    func exportPDFReportPanel() {
        guard currentURL != nil else {
            showError("Load a media file before exporting a PDF report.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Save PDF"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { [weak self] in
                await self?.exportPDFReport(to: url)
            }
        }
    }

    func handleKeyDown(event: NSEvent) {
        // Cmd+[ / Cmd+] : 플레이리스트 이동
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                switch chars {
                case "[": prevPlaylistItem(); return
                case "]": nextPlaylistItem(); return
                default: break
                }
            }
            return
        }

        let isRepeat = event.isARepeat

        // Step / navigate keys: allowed to repeat
        switch event.keyCode {
        case 123: // left arrow
            stepOrNavigateBackward()
            return
        case 124: // right arrow
            stepOrNavigateForward()
            return
        case 49: // space — no repeat for play/pause
            if !isRepeat { gridPlayPause() }
            return
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return }
        for char in chars {
            switch char {
            case ",":
                stepOrNavigateBackward()  // allow repeat
            case ".":
                stepOrNavigateForward()   // allow repeat
            default:
                if isRepeat { continue }  // only step keys repeat
                switch char {
                case "j":
                    if gridLayout != .single && gridSyncEnabled {
                        gridSlots.forEach { $0.controller.handleJ() }
                    } else { activeController.handleJ() }
                case "k":
                    if gridLayout != .single && gridSyncEnabled {
                        gridSlots.forEach { $0.controller.handleK() }
                    } else { activeController.handleK() }
                case "l":
                    if gridLayout != .single && gridSyncEnabled {
                        gridSlots.forEach { $0.controller.handleL() }
                    } else { activeController.handleL() }
                case "i": activeController.setInPoint()
                case "o": activeController.setOutPoint()
                case "u": activeController.clearInOut()
                case "p": activeController.toggleLooping()
                case "t": lutEnabled.toggle()
                case "m": activeController.toggleMute()
                case "f": pendingZoomCommand = .fit
                case "g": pendingZoomCommand = .fill
                case "1": pendingZoomCommand = .pixelPerfect
                case "h": scopeEnabled.toggle()
                case "v": falseColorEnabled.toggle()
                case "c":
                    if compareEnabled {
                        compareEnabled = false
                    } else if comparePixelBuffer != nil {
                        compareEnabled = true
                    }
                default: break
                }
            }
        }
    }

    private func stepOrNavigateBackward() {
        if gridLayout != .single {
            activeController.stepBackward()
            return
        }
        if currentImage != nil {
            navigateToPreviousImage()
        } else {
            playerController.stepBackward()
        }
    }

    private func stepOrNavigateForward() {
        if gridLayout != .single {
            activeController.stepForward()
            return
        }
        if currentImage != nil {
            navigateToNextImage()
        } else {
            playerController.stepForward()
        }
    }

    private func navigateToPreviousImage() {
        guard !folderImages.isEmpty, folderImageIndex > 0 else { return }
        folderImageIndex -= 1
        loadFolderImage(at: folderImageIndex)
    }

    private func navigateToNextImage() {
        guard !folderImages.isEmpty, folderImageIndex < folderImages.count - 1 else { return }
        folderImageIndex += 1
        loadFolderImage(at: folderImageIndex)
    }

    private func loadFolderImage(at index: Int) {
        let url = folderImages[index]
        guard let image = loadStillImage(url: url) else {
            showError("Failed to load image: \(url.lastPathComponent)")
            return
        }

        // EXR 채널 상태 업데이트
        exrInfo = nil
        exrBaseImage = nil
        exrChannelMode = .composite
        if url.pathExtension.lowercased() == "exr" {
            exrInfo = EXRInspector.inspect(url: url)
            exrBaseImage = image
        }

        currentImage = image
        currentURL = url
        addRecent(url)
        startReview(for: url)
        log.info("Navigate image [\(index, privacy: .public)]: \(url.lastPathComponent, privacy: .public)")
    }

    func setCompareFrame() {
        captureCompareRequest = true
    }

    // MARK: - Playlist (D)

    private func updatePlaylistIndex(for url: URL) {
        playlistIndex = recentURLs.firstIndex(of: url) ?? -1
    }

    func nextPlaylistItem() {
        guard !recentURLs.isEmpty else { return }
        let next = playlistIndex < recentURLs.count - 1 ? playlistIndex + 1 : 0
        open(url: recentURLs[next])
    }

    func prevPlaylistItem() {
        guard !recentURLs.isEmpty else { return }
        let prev = playlistIndex > 0 ? playlistIndex - 1 : recentURLs.count - 1
        open(url: recentURLs[prev])
    }

    // MARK: - Full Screen (F)

    func toggleFullScreen() {
        NSApplication.shared.mainWindow?.toggleFullScreen(nil)
    }

    private func clearCompare() {
        compareEnabled = false
        comparePixelBuffer = nil
        captureCompareRequest = false
    }

    private func openVideo(url: URL) {
        currentImage = nil
        folderImages = []
        folderImageIndex = 0
        clearCompare()
        currentMetadata = .empty
        playerController.openVideo(url: url)
        startReview(for: url)
        updatePlaylistIndex(for: url)
        if let error = playerController.lastErrorMessage {
            showError(error)
        }
        log.info("Opened video: \(url.lastPathComponent, privacy: .public)")
        Task { [weak self, url] in
            guard let self else { return }
            let meta = await MediaMetadataExtractor.extract(from: url)
            self.currentMetadata = meta
        }
    }

    private func openImage(url: URL) {
        clearCompare()
        currentMetadata = .empty
        Task { [weak self, url] in
            let meta = await Task.detached(priority: .utility) {
                MediaMetadataExtractor.extractImage(from: url)
            }.value
            self?.currentMetadata = meta
        }
        playerController.clear()
        playerController.enterPrecisionMode()

        // EXR 채널 상태 초기화
        exrInfo = nil
        exrBaseImage = nil
        exrChannelMode = .composite

        if let image = loadStillImage(url: url) {
            // EXR이면 헤더 파싱 + 원본 보관
            if url.pathExtension.lowercased() == "exr" {
                exrInfo = EXRInspector.inspect(url: url)
                exrBaseImage = image
            }
            currentImage = image
            startReview(for: url)
            buildFolderImageList(from: url)
            log.info("Opened image: \(url.lastPathComponent, privacy: .public)")
        } else {
            showError("Failed to load image: \(url.lastPathComponent)")
        }
    }

    /// Loads a still image from any supported format (PNG/TIFF/JPEG via ImageIO,
    /// EXR via Core Image fallback, DPX via custom decoder).
    private func loadStillImage(url: URL) -> NSImage? {
        let ext = url.pathExtension.lowercased()

        // DPX: custom 10-bit decoder
        if ext == "dpx" {
            guard let cg = try? DPXDecoder.decode(url: url) else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }

        // Standard formats (PNG, TIFF, JPEG, EXR on macOS 10.14+) via ImageIO
        if let image = NSImage(contentsOf: url) { return image }

        // EXR fallback: Core Image can read HDR EXR files even when ImageIO fails
        if ext == "exr" {
            guard let ci = CIImage(contentsOf: url),
                  let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }

        return nil
    }

    private func buildFolderImageList(from url: URL) {
        let folder = url.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        folderImages = files
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        folderImageIndex = folderImages.firstIndex(of: url) ?? 0
        log.info("Folder images: \(self.folderImages.count, privacy: .public), index: \(self.folderImageIndex, privacy: .public)")
    }

    private func openLUT(url: URL) {
        do {
            let cube = try LUTCube.load(url: url)
            lutCube = cube
            lutEnabled = true
            lutName = url.lastPathComponent
            log.info("Loaded LUT: \(url.lastPathComponent, privacy: .public)")
        } catch {
            showError("Failed to load LUT: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        log.error("UI error: \(message, privacy: .public)")
        errorMessage = message
        isShowingError = true
    }

    private func exportPackage(to destinationURL: URL) async {
        guard let currentURL else {
            showError("No media loaded.")
            return
        }
        guard let reviewSession, let asset = reviewSession.asset, let reviewItem = reviewSession.reviewItem else {
            showError("Review data not available for export.")
            return
        }
        playerController.prepareForExportStill()

        let frameIndex = playerController.frameIndex
        let baseName = currentURL.deletingPathExtension().lastPathComponent
        let packageName = ExportNaming.packageName(baseName: baseName, frameIndex: frameIndex, date: Date())

        do {
            let baseImage = try await captureBaseImage()
            let hud = exportBurnInEnabled ? HUDOverlayData(
                timecode: playerController.timecode,
                frameIndex: frameIndex,
                fps: playerController.fps,
                resolution: playerController.resolution
            ) : nil
            let overlayImage = ExportOverlayBuilder.overlayImage(
                size: CGSize(width: baseImage.width, height: baseImage.height),
                hud: hud,
                annotations: reviewSession.annotations(forFrame: frameIndex)
            )

            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PolePlayer"
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
            let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

            let startTimecode = TimecodeFormatter.timecodeString(frameIndex: 0, fps: playerController.fps)
            let context = ExportContext(
                destinationURL: destinationURL,
                packageName: packageName,
                stillBaseName: baseName,
                frameIndex: frameIndex,
                timecode: startTimecode,
                fps: playerController.fps,
                durationFrames: max(playerController.durationFrames, 1),
                baseImage: baseImage,
                overlayImage: overlayImage,
                asset: asset,
                reviewItem: reviewItem,
                annotations: reviewSession.annotations,
                lutName: lutName,
                lutPath: nil,
                lutHash: nil,
                lutIntensity: lutIntensity,
                lutEnabled: lutEnabled,
                appName: appName,
                appVersion: appVersion,
                appBuild: appBuild,
                authorName: NSUserName()
            )

            _ = try ExportCoordinator.exportPackage(context: context)
            log.info("Exported package: \(packageName, privacy: .public)")
        } catch {
            showError("Export failed: \(error.localizedDescription)")
        }
    }

    private func exportPDFReport(to destinationURL: URL) async {
        guard let currentURL else {
            showError("No media loaded.")
            return
        }
        guard let reviewSession, let asset = reviewSession.asset, let reviewItem = reviewSession.reviewItem else {
            showError("Review data not available for PDF report.")
            return
        }
        playerController.prepareForExportStill()

        let frameIndex = playerController.frameIndex
        let baseName = currentURL.deletingPathExtension().lastPathComponent
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmmss"
        let outputURL = destinationURL.appendingPathComponent("\(baseName)_report_\(df.string(from: Date())).pdf")

        do {
            let baseImage = try await captureBaseImage()
            let hud = exportBurnInEnabled ? HUDOverlayData(
                timecode: playerController.timecode,
                frameIndex: frameIndex,
                fps: playerController.fps,
                resolution: playerController.resolution
            ) : nil
            let overlayImage = ExportOverlayBuilder.overlayImage(
                size: CGSize(width: baseImage.width, height: baseImage.height),
                hud: hud,
                annotations: reviewSession.annotations(forFrame: frameIndex)
            )
            let appName    = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "PolePlayer"
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
            let appBuild   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
            let startTC    = TimecodeFormatter.timecodeString(frameIndex: 0, fps: playerController.fps)

            let context = ExportContext(
                destinationURL: destinationURL,
                packageName: baseName,
                stillBaseName: baseName,
                frameIndex: frameIndex,
                timecode: startTC,
                fps: playerController.fps,
                durationFrames: max(playerController.durationFrames, 1),
                baseImage: baseImage,
                overlayImage: overlayImage,
                asset: asset,
                reviewItem: reviewItem,
                annotations: reviewSession.annotations,
                lutName: lutName,
                lutPath: nil,
                lutHash: nil,
                lutIntensity: lutIntensity,
                lutEnabled: lutEnabled,
                appName: appName,
                appVersion: appVersion,
                appBuild: appBuild,
                authorName: NSUserName()
            )
            try ExportCoordinator.exportPDFReport(context: context, outputURL: outputURL)
            log.info("PDF report exported: \(outputURL.lastPathComponent, privacy: .public)")
        } catch {
            showError("PDF report failed: \(error.localizedDescription)")
        }
    }

    private func captureBaseImage() async throws -> CGImage {
        if let currentImage {
            guard let cgImage = currentImage.cgImageForExport() else {
                throw NSError(domain: "PolePlayer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to read still image."]) 
            }
            return cgImage
        }
        return try await playerController.captureStillImage()
    }

    private func startReview(for url: URL) {
        guard let reviewSession else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let asset = try await ReviewAssetBuilder.build(url: url)
                reviewSession.loadOrCreate(asset: asset, defaultTitle: url.lastPathComponent, currentFrame: self.playerController.frameIndex)
            } catch {
                self.log.error("Review asset hash failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Grid (Phase 91)

    /// 지정 슬롯에 URL을 엽니다 (비디오 전용).
    func openInSlot(_ index: Int, url: URL) {
        guard index < gridSlots.count else { return }
        addRecent(url)
        gridSlots[index].open(url: url)
    }

    /// 재생/일시정지 토글 — syncEnabled이면 모든 슬롯, 아니면 활성 슬롯.
    func gridPlayPause() {
        if gridLayout != .single && gridSyncEnabled {
            gridSlots.forEach { $0.controller.togglePlayPause() }
        } else {
            activeController.togglePlayPause()
        }
    }

    /// gridLayout 변경에 맞춰 gridSlots 배열을 조정합니다.
    private func updateGridSlots() {
        let target = gridLayout.slotCount
        if gridSlots.count < target {
            let extra = (gridSlots.count..<target).map { _ in GridSlot() }
            gridSlots.append(contentsOf: extra)
        } else if gridSlots.count > target {
            gridSlots.suffix(gridSlots.count - target).forEach { $0.clear() }
            gridSlots = Array(gridSlots.prefix(target))
        }
        activeSlotIndex = min(activeSlotIndex, max(0, gridSlots.count - 1))
    }

    // MARK: - EXR Channel

    private func applyEXRChannel(mode: EXRChannelMode) {
        guard let base = exrBaseImage else { return }
        currentImage = EXRChannelProcessor.process(source: base, mode: mode) ?? base
    }

    private func addRecent(_ url: URL) {
        var updated = recentURLs.filter { $0 != url }
        updated.insert(url, at: 0)
        if updated.count > Self.maxRecentCount {
            updated = Array(updated.prefix(Self.maxRecentCount))
        }
        recentURLs = updated
        UserDefaults.standard.set(updated.map(\.path), forKey: Self.recentURLsKey)
    }

    private static func loadRecentURLs() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: recentURLsKey) ?? []
        return paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func makeReviewStore() -> ReviewStore? {
        do {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let directory = base?.appendingPathComponent("PolePlayer", isDirectory: true)
            if let directory {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let dbURL = directory.appendingPathComponent("review.sqlite")
                return try ReviewStore(databaseURL: dbURL)
            }
        } catch {
            Logger(subsystem: "PolePlayer", category: "AppState").error("ReviewStore init failed: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }
}

private extension NSImage {
    func cgImageForExport() -> CGImage? {
        var rect = NSRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
