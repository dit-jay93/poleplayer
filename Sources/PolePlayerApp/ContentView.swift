import AppKit
import PlayerCore
import RenderCore
import Review
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: appState.currentURL?.lastPathComponent ?? "No Media Loaded",
                onOpen: appState.openPanel,
                onOpenLUT: appState.openLUTPanel,
                onExport: appState.exportPanel,
                lutName: appState.lutName,
                lutEnabled: $appState.lutEnabled,
                lutIntensity: $appState.lutIntensity,
                burnInEnabled: $appState.exportBurnInEnabled,
                isAnnotating: $appState.isAnnotating,
                reviewSession: appState.reviewSession
            )

            GeometryReader { _ in
                ZStack {
                    ViewerSurface(
                        player: appState.playerController,
                        image: appState.currentImage,
                        lutCube: appState.lutCube,
                        lutEnabled: appState.lutEnabled,
                        lutIntensity: appState.lutIntensity,
                        reviewSession: appState.reviewSession,
                        isAnnotating: appState.isAnnotating
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
    let onOpenLUT: () -> Void
    let onExport: () -> Void
    let lutName: String?
    @Binding var lutEnabled: Bool
    @Binding var lutIntensity: Double
    @Binding var burnInEnabled: Bool
    @Binding var isAnnotating: Bool
    let reviewSession: ReviewSession?

    var body: some View {
        HStack(spacing: 12) {
            Text("PolePlayer")
                .font(AppFont.title2)
            Divider()
            Text(title)
                .font(AppFont.body)
                .lineLimit(1)
            Spacer()
            if let lutName {
                Toggle("LUT", isOn: $lutEnabled)
                    .toggleStyle(.switch)
                    .font(AppFont.caption)
                Slider(value: $lutIntensity, in: 0...1)
                    .frame(width: 120)
                    .disabled(!lutEnabled)
                Text(lutName)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Toggle("Burn-in", isOn: $burnInEnabled)
                .toggleStyle(.switch)
                .font(AppFont.caption)
            if let reviewSession {
                ReviewControls(
                    session: reviewSession,
                    isAnnotating: $isAnnotating
                )
            }
            Button("LUT…", action: onOpenLUT)
                .buttonStyle(.bordered)
                .font(AppFont.body)
            Button("Export…", action: onExport)
                .buttonStyle(.bordered)
                .font(AppFont.body)
            Button("Open…", action: onOpen)
                .buttonStyle(.borderedProminent)
                .font(AppFont.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.topBarBackground)
    }
}

private struct ReviewControls: View {
    @ObservedObject var session: ReviewSession
    @Binding var isAnnotating: Bool

    var body: some View {
        Toggle("Annotate", isOn: $isAnnotating)
            .toggleStyle(.switch)
            .font(AppFont.caption)

        Toggle("Select", isOn: selectionBinding)
            .toggleStyle(.switch)
            .font(AppFont.caption)
            .disabled(!isAnnotating)

        Picker("Tool", selection: toolBinding) {
            Text("Pen").tag(AnnotationType.pen)
            Text("Rect").tag(AnnotationType.rect)
            Text("Circle").tag(AnnotationType.circle)
            Text("Arrow").tag(AnnotationType.arrow)
            Text("Text").tag(AnnotationType.text)
        }
        .pickerStyle(.segmented)
        .frame(width: 320)
        .disabled(!isAnnotating || session.isSelecting)

        if let selected = session.selectedAnnotation {
            Button("Delete") {
                session.deleteSelected()
            }
            .buttonStyle(.bordered)
            .font(AppFont.caption)

            if selected.type == .text {
                TextField("Text", text: selectedTextBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
            }
        }
    }

    private var toolBinding: Binding<AnnotationType> {
        Binding(
            get: { session.activeTool },
            set: { session.activeTool = $0 }
        )
    }

    private var selectionBinding: Binding<Bool> {
        Binding(
            get: { session.isSelecting },
            set: { value in
                session.isSelecting = value
                if !value {
                    session.clearSelection()
                }
            }
        )
    }

    private var selectedTextBinding: Binding<String> {
        Binding(
            get: { session.selectedText ?? "" },
            set: { session.updateSelectedText($0) }
        )
    }
}

private struct ViewerSurface: View {
    @ObservedObject var player: PlayerController
    let image: NSImage?
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double
    let reviewSession: ReviewSession?
    let isAnnotating: Bool

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
                    isAnnotating: isAnnotating
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
                    isAnnotating: isAnnotating
                )
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
                HUDRow(label: "PrecSrc", value: precisionSource)
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

    private var precisionSource: String {
        if player.debugLastPrecisionAt == 0 { return "—" }
        let age = CACurrentMediaTime() - player.debugLastPrecisionAt
        if age < 2.0 {
            return "\(player.debugLastPrecisionSource) (recent)"
        }
        return "—"
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
