import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import os
import PlayerCore
import RenderCore
import Review

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

    let reviewSession: ReviewSession?

    let playerController = PlayerController()
    private let log = Logger(subsystem: "PolePlayer", category: "AppState")
    private var cancellables: Set<AnyCancellable> = []
    private let reviewStore: ReviewStore?

    private let videoExtensions = ["mov", "mp4", "m4v"]
    private let imageExtensions = ["png", "jpg", "jpeg", "tif", "tiff"]

    init() {
        if let store = AppState.makeReviewStore() {
            self.reviewStore = store
            self.reviewSession = ReviewSession(store: store)
        } else {
            self.reviewStore = nil
            self.reviewSession = nil
        }
        playerController.$lastErrorMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.showError(message)
            }
            .store(in: &cancellables)
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .png,
            .tiff,
            .jpeg
        ]
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

    func open(url: URL) {
        let ext = url.pathExtension.lowercased()
        currentURL = url
        if imageExtensions.contains(ext) {
            openImage(url: url)
            return
        }
        if videoExtensions.contains(ext) {
            openVideo(url: url)
            return
        }
        showError("Unsupported file type: .\(ext)")
    }

    func handleKeyDown(event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            return
        }

        switch event.keyCode {
        case 123: // left arrow
            playerController.stepBackward()
            return
        case 124: // right arrow
            playerController.stepForward()
            return
        case 49: // space
            playerController.togglePlayPause()
            return
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return }
        for char in chars {
            switch char {
            case "j":
                playerController.handleJ()
            case "k":
                playerController.handleK()
            case "l":
                playerController.handleL()
            case "i":
                playerController.setInPoint()
            case "o":
                playerController.setOutPoint()
            case "u":
                playerController.clearInOut()
            case "p":
                playerController.toggleLooping()
            case "t":
                lutEnabled.toggle()
            case ",":
                playerController.stepBackward()
            case ".":
                playerController.stepForward()
            default:
                break
            }
        }
    }

    private func openVideo(url: URL) {
        currentImage = nil
        playerController.openVideo(url: url)
        startReview(for: url)
        if let error = playerController.lastErrorMessage {
            showError(error)
        }
        log.info("Opened video: \(url.lastPathComponent, privacy: .public)")
    }

    private func openImage(url: URL) {
        playerController.clear()
        playerController.enterPrecisionMode()
        if let image = NSImage(contentsOf: url) {
            currentImage = image
            startReview(for: url)
            log.info("Opened image: \(url.lastPathComponent, privacy: .public)")
        } else {
            showError("Failed to load image: \(url.lastPathComponent)")
        }
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
