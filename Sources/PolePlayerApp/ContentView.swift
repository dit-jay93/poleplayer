import AppKit
import PlayerCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: appState.currentURL?.lastPathComponent ?? "No Media Loaded",
                onOpen: appState.openPanel
            )

            GeometryReader { _ in
                ZStack {
                    ViewerSurface(
                        player: appState.playerController,
                        image: appState.currentImage
                    )

                HUDOverlay(
                    player: appState.playerController,
                    image: appState.currentImage
                )

                ModePill(player: appState.playerController)
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.viewerBackground)
                .overlay(KeyCaptureView { event in
                    appState.handleKeyDown(event: event)
                })
            }

            TransportBar(
                player: appState.playerController,
                onPlayPause: appState.playerController.togglePlayPause,
                onStepBack: appState.playerController.stepBackward,
                onStepForward: appState.playerController.stepForward
            )
        }
        .background(Theme.appBackground)
        .alert("Error", isPresented: $appState.isShowingError) {
            Button("OK") {
                appState.isShowingError = false
            }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
    }
}

private struct TopBar: View {
    let title: String
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("PolePlayer")
                .font(AppFont.title2)
            Divider()
            Text(title)
                .font(AppFont.body)
                .lineLimit(1)
            Spacer()
            Button("Open…", action: onOpen)
                .buttonStyle(.borderedProminent)
                .font(AppFont.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.topBarBackground)
    }
}

private struct ViewerSurface: View {
    @ObservedObject var player: PlayerController
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else if player.hasVideo {
                MetalVideoContainer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(4)
            } else {
                PlaceholderView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Drop a file or click Open")
                .font(AppFont.title3)
            Text("Supported: ProRes / H.264 / H.265 + PNG / TIFF / JPG")
                .font(AppFont.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HUDOverlay: View {
    @ObservedObject var player: PlayerController
    let image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HUDRow(label: "TC", value: player.timecode)
            HUDRow(label: "Frame", value: String(player.frameIndex))
            HUDRow(label: "FPS", value: hudFPS)
            HUDRow(label: "Res", value: hudResolution)
            if player.hasVideo {
                HUDRow(label: "Src", value: player.debugFrameSource)
                HUDRow(label: "VFrames", value: String(player.debugVideoFrames))
                HUDRow(label: "FSize", value: debugFrameSize)
                HUDRow(label: "LastF", value: debugLastFrame)
                HUDRow(label: "RTicks", value: String(player.debugRenderTicks))
                HUDRow(label: "LastR", value: debugLastRender)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hudFPS: String {
        if player.fps > 0 { return String(format: "%.3f", player.fps) }
        return "—"
    }

    private var hudResolution: String {
        if let image {
            return "\(Int(image.size.width))x\(Int(image.size.height))"
        }
        if player.resolution != .zero {
            return "\(Int(player.resolution.width))x\(Int(player.resolution.height))"
        }
        return "—"
    }

    private var debugFrameSize: String {
        if player.debugFrameSize == .zero { return "—" }
        return "\(Int(player.debugFrameSize.width))x\(Int(player.debugFrameSize.height))"
    }

    private var debugLastFrame: String {
        if player.debugLastFrameAt == 0 { return "—" }
        return String(format: "%.2f", player.debugLastFrameAt)
    }

    private var debugLastRender: String {
        if player.debugLastRenderAt == 0 { return "—" }
        return String(format: "%.2f", player.debugLastRenderAt)
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
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.hudBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ModePill: View {
    @ObservedObject var player: PlayerController

    var body: some View {
        Text(player.mode.rawValue)
            .font(AppFont.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.modePillBackground)
            .foregroundStyle(Theme.primaryText)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(12)
    }
}
