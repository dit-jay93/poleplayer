import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers
import os
import PlayerCore

@MainActor
final class AppState: ObservableObject {
    @Published var currentImage: NSImage? = nil
    @Published var currentURL: URL? = nil
    @Published var errorMessage: String? = nil
    @Published var isShowingError: Bool = false

    let playerController = PlayerController()
    private let log = Logger(subsystem: "PolePlayer", category: "AppState")
    private var cancellables: Set<AnyCancellable> = []

    private let videoExtensions = ["mov", "mp4", "m4v"]
    private let imageExtensions = ["png", "jpg", "jpeg", "tif", "tiff"]

    init() {
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
            log.info("Opened image: \(url.lastPathComponent, privacy: .public)")
        } else {
            showError("Failed to load image: \(url.lastPathComponent)")
        }
    }

    private func showError(_ message: String) {
        log.error("UI error: \(message, privacy: .public)")
        errorMessage = message
        isShowingError = true
    }
}
