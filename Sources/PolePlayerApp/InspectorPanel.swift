import DecodeKit
import Review
import SwiftUI

// MARK: - Inspector Panel Root

struct InspectorPanel: View {
    @Binding var isAnnotating: Bool
    let reviewSession: ReviewSession?
    @Binding var lutEnabled: Bool
    @Binding var lutIntensity: Double
    let lutName: String?
    let libraryLUTs: [URL]
    let onOpenLUT: () -> Void
    let onOpenLUTLibrary: () -> Void
    let onLoadLibraryLUT: (URL) -> Void
    @Binding var burnInEnabled: Bool
    let onExport: () -> Void
    let onExportPDF: () -> Void
    let currentMetadata: MediaMetadata
    // EXR (Phase 90)
    let exrInfo: EXRInfo?
    @Binding var exrChannelMode: EXRChannelMode

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Media Info (B) ─────────────────────────────────────
                if currentMetadata != .empty {
                    MetadataSection(metadata: currentMetadata)
                    InspectorDivider()
                }

                // ── EXR 채널 (Phase 90) ───────────────────────────────
                if let info = exrInfo {
                    EXRChannelSection(info: info, mode: $exrChannelMode)
                    InspectorDivider()
                }

                // ── Annotate / Tools ───────────────────────────────────
                AnnotateSection(isAnnotating: $isAnnotating, session: reviewSession)

                InspectorDivider()

                // ── LUT ────────────────────────────────────────────────
                LUTSection(
                    enabled: $lutEnabled,
                    intensity: $lutIntensity,
                    lutName: lutName,
                    libraryLUTs: libraryLUTs,
                    onOpenLUT: onOpenLUT,
                    onOpenLUTLibrary: onOpenLUTLibrary,
                    onLoadLibraryLUT: onLoadLibraryLUT
                )

                InspectorDivider()

                // ── Notes ──────────────────────────────────────────────
                if let session = reviewSession {
                    NotesSection(session: session)
                    InspectorDivider()
                }

                // ── Export ─────────────────────────────────────────────
                ExportSection(burnInEnabled: $burnInEnabled, onExport: onExport, onExportPDF: onExportPDF)
            }
        }
        .background(.regularMaterial)
    }
}

// MARK: - Section Helpers

private struct InspectorSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.sectionLabel)
                .kerning(0.8)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}

private struct InspectorDivider: View {
    var body: some View {
        Divider().background(Theme.panelDivider)
    }
}

// MARK: - Annotate Section

private struct AnnotateSection: View {
    @Binding var isAnnotating: Bool
    let session: ReviewSession?

    var body: some View {
        InspectorSection(label: "Annotate") {
            Toggle(isOn: $isAnnotating) {
                Label("Draw Annotations", systemImage: "pencil.tip")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .toggleStyle(.switch)

            if isAnnotating, let session {
                AnnotationToolPalette(session: session)
            }
        }
    }
}

// MARK: - Annotation Tool Palette

private struct AnnotationToolPalette: View {
    @ObservedObject var session: ReviewSession

    private let tools: [(AnnotationType, String, String)] = [
        (.pen,    "scribble.variable", "Pen"),
        (.rect,   "rectangle",          "Rectangle"),
        (.circle, "circle",             "Circle"),
        (.arrow,  "arrow.up.right",     "Arrow"),
        (.text,   "textformat",         "Text"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tool row
            HStack(spacing: 5) {
                PaletteButton(
                    icon: "cursorarrow",
                    label: "Select",
                    isActive: session.isSelecting
                ) {
                    let nowSelecting = !session.isSelecting
                    session.isSelecting = nowSelecting
                    if !nowSelecting { session.clearSelection() }
                }

                Divider().frame(height: 22).opacity(0.3)

                ForEach(tools, id: \.0) { (tool, icon, label) in
                    PaletteButton(
                        icon: icon,
                        label: label,
                        isActive: !session.isSelecting && session.activeTool == tool
                    ) {
                        session.isSelecting = false
                        session.activeTool = tool
                    }
                }
            }

            // Selection actions
            if session.isSelecting, let selected = session.selectedAnnotation {
                HStack(spacing: 6) {
                    if selected.type == .text {
                        TextField("Text", text: Binding(
                            get: { session.selectedText ?? "" },
                            set: { session.updateSelectedText($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(AppFont.caption)
                    }
                    Spacer(minLength: 0)
                    Button {
                        session.deleteSelected()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.35))
                    .help("Delete selected annotation")
                }
            }
        }
    }
}

private struct PaletteButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Theme.secondaryText)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - LUT Section

private struct LUTSection: View {
    @Binding var enabled: Bool
    @Binding var intensity: Double
    let lutName: String?
    let libraryLUTs: [URL]
    let onOpenLUT: () -> Void
    let onOpenLUTLibrary: () -> Void
    let onLoadLibraryLUT: (URL) -> Void

    var body: some View {
        InspectorSection(label: "LUT") {
            // Toggle + name
            HStack(spacing: 8) {
                Toggle("", isOn: $enabled)
                    .toggleStyle(.switch)
                    .disabled(lutName == nil)
                    .labelsHidden()
                Text(lutName ?? "No LUT loaded")
                    .font(AppFont.body)
                    .foregroundStyle(lutName != nil ? Theme.primaryText : Theme.secondaryText.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Intensity slider
            if lutName != nil {
                HStack(spacing: 6) {
                    Text("Intensity")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: true, vertical: false)
                    Slider(value: $intensity, in: 0...1)
                        .disabled(!enabled)
                }
            }

            // Actions
            Button("Open LUT File…", action: onOpenLUT)
                .buttonStyle(.plain)
                .font(AppFont.body)
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: true, vertical: false)

            Button("Set Library Folder…", action: onOpenLUTLibrary)
                .buttonStyle(.plain)
                .font(AppFont.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: true, vertical: false)

            // Library list
            if !libraryLUTs.isEmpty {
                Divider().opacity(0.25)
                Text("Library")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.sectionLabel)
                    .kerning(0.6)

                ForEach(libraryLUTs, id: \.self) { url in
                    Button(action: { onLoadLibraryLUT(url) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "cube")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.secondaryText.opacity(0.5))
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(AppFont.caption)
                                .foregroundStyle(
                                    lutName == url.lastPathComponent ? Color.accentColor : Theme.primaryText
                                )
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Notes Section

private struct NotesSection: View {
    @ObservedObject var session: ReviewSession
    @State private var editTitle: String = ""
    @State private var editTags: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        InspectorSection(label: "Notes") {
            if isEditing {
                TextField("Title", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)

                TextField("Tags (comma-separated)", text: $editTags)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)

                HStack {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: true, vertical: false)

                    Spacer()

                    Button("Save") {
                        save()
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .font(AppFont.caption)
                    .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let title = session.reviewItem?.title, !title.isEmpty {
                            Text(title)
                                .font(AppFont.body)
                                .foregroundStyle(Theme.primaryText)
                        } else {
                            Text("No title")
                                .font(AppFont.body)
                                .foregroundStyle(Theme.secondaryText.opacity(0.4))
                        }
                    }
                    .lineLimit(1)

                    if let tags = session.reviewItem?.tags, !tags.isEmpty {
                        Text(tags.joined(separator: ", "))
                            .font(AppFont.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                    }

                    Text("\(session.annotations.count) annotation\(session.annotations.count == 1 ? "" : "s")")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                }

                Button("Edit…") {
                    editTitle = session.reviewItem?.title ?? ""
                    editTags = session.reviewItem?.tags.joined(separator: ", ") ?? ""
                    isEditing = true
                }
                .buttonStyle(.plain)
                .font(AppFont.caption)
                .foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func save() {
        session.updateTitle(editTitle)
        let tags = editTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        session.updateTags(tags)
    }
}

// MARK: - Metadata Section (B)

private struct MetadataSection: View {
    let metadata: MediaMetadata

    var body: some View {
        InspectorSection(label: "Media Info") {
            MetaRow("File",       metadata.fileName)
            MetaRow("Size",       metadata.fileSize)
            MetaRow("Container",  metadata.container)
            if !metadata.duration.isEmpty     { MetaRow("Duration",  metadata.duration) }
            if !metadata.resolution.isEmpty   { MetaRow("Resolution", metadata.resolution) }
            if !metadata.frameRate.isEmpty    { MetaRow("Frame Rate", metadata.frameRate) }
            if !metadata.videoCodec.isEmpty   { MetaRow("V Codec",   metadata.videoCodec) }
            if !metadata.videoBitRate.isEmpty { MetaRow("V Bitrate", metadata.videoBitRate) }
            if !metadata.bitDepth.isEmpty     { MetaRow("Bit Depth", metadata.bitDepth) }
            if !metadata.colorSpace.isEmpty   { MetaRow("Color",     metadata.colorSpace) }
            if !metadata.hdrMode.isEmpty      { MetaRow("Transfer",  metadata.hdrMode) }
            if !metadata.audioCodec.isEmpty   { MetaRow("A Codec",   metadata.audioCodec) }
            if !metadata.audioChannels.isEmpty { MetaRow("Channels", metadata.audioChannels) }
            if !metadata.audioSampleRate.isEmpty { MetaRow("Sample",  metadata.audioSampleRate) }
            if !metadata.audioBitRate.isEmpty { MetaRow("A Bitrate", metadata.audioBitRate) }
        }
    }
}

private struct MetaRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(AppFont.caption)
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - EXR Channel Section (Phase 90)

private struct EXRChannelSection: View {
    let info: EXRInfo
    @Binding var mode: EXRChannelMode

    var body: some View {
        InspectorSection(label: "EXR Channels") {
            // 채널 모드 선택 버튼
            HStack(spacing: 4) {
                ForEach(EXRChannelMode.allCases, id: \.self) { m in
                    Button(m.label) { mode = m }
                        .buttonStyle(EXRModeButtonStyle(isActive: mode == m))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            // 채널 목록 (레이어별 그룹)
            let layers = info.layerNames
            ForEach(layers, id: \.self) { layer in
                let channels = info.groupedByLayer[layer] ?? []
                VStack(alignment: .leading, spacing: 2) {
                    if !layer.isEmpty {
                        Text(layer)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.sectionLabel)
                            .kerning(0.5)
                    }
                    ForEach(channels, id: \.name) { ch in
                        HStack(spacing: 6) {
                            Text(ch.shortName)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(channelColor(ch.shortName))
                                .frame(width: 20, alignment: .leading)
                            Text(pixelTypeLabel(ch.pixelType))
                                .font(AppFont.caption)
                                .foregroundStyle(Theme.secondaryText.opacity(0.6))
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if info.isMultiPart {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                    Text("Multi-part EXR — showing first part")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.secondaryText.opacity(0.5))
                }
            }
        }
    }

    private func channelColor(_ name: String) -> Color {
        switch name.uppercased() {
        case "R": return Color(red: 1.0, green: 0.35, blue: 0.35)
        case "G": return Color(red: 0.3, green: 0.9,  blue: 0.4)
        case "B": return Color(red: 0.35, green: 0.55, blue: 1.0)
        case "A": return Theme.secondaryText
        default:  return Theme.primaryText
        }
    }

    private func pixelTypeLabel(_ type: EXRChannelInfo.PixelType) -> String {
        switch type {
        case .uint:  return "uint32"
        case .half:  return "half16"
        case .float: return "float32"
        }
    }
}

private struct EXRModeButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: isActive ? .semibold : .regular, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05))
            )
            .foregroundStyle(isActive ? Color.accentColor : Theme.secondaryText)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Export Section

private struct ExportSection: View {
    @Binding var burnInEnabled: Bool
    let onExport: () -> Void
    let onExportPDF: () -> Void

    var body: some View {
        InspectorSection(label: "Export") {
            Toggle(isOn: $burnInEnabled) {
                Label("Burn-in Overlay", systemImage: "text.below.photo")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .toggleStyle(.switch)

            Button(action: onExport) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("Export…")
                        .font(AppFont.body)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: onExportPDF) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 12))
                    Text("PDF Report…")
                        .font(AppFont.body)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}
