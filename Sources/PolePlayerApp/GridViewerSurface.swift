import PlayerCore
import RenderCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Grid Viewer Surface

/// 멀티클립 그리드 레이아웃 뷰.
/// 각 셀은 독립적인 `GridSlot`(PlayerController)을 렌더링하고
/// 파일 드래그 앤 드롭을 지원합니다.
struct GridViewerSurface: View {
    let slots: [GridSlot]
    let layout: GridLayout
    @Binding var activeSlotIndex: Int
    let syncEnabled: Bool
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double
    let onDropURL: (Int, URL) -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: layout.columns)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                GridCellView(
                    slot: slot,
                    isActive: activeSlotIndex == index,
                    lutCube: lutCube,
                    lutEnabled: lutEnabled,
                    lutIntensity: lutIntensity,
                    onTap: { activeSlotIndex = index },
                    onDrop: { url in onDropURL(index, url) }
                )
            }
        }
        .background(Color.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid Cell

private struct GridCellView: View {
    @ObservedObject var slot: GridSlot
    let isActive: Bool
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double
    let onTap: () -> Void
    let onDrop: (URL) -> Void

    @State private var isDragTargeted = false
    @State private var zoomCommand: ZoomCommand? = nil
    @State private var captureRequest: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // ── 콘텐츠 ───────────────────────────────────────────
                if slot.controller.hasVideo {
                    MetalVideoContainer(
                        player: slot.controller,
                        lutCube: lutCube,
                        lutEnabled: lutEnabled,
                        lutIntensity: lutIntensity,
                        reviewSession: nil,
                        isAnnotating: false,
                        zoomCommand: $zoomCommand,
                        scopeEnabled: false,
                        onHistogram: nil,
                        onWaveform: nil,
                        onVectorscope: nil,
                        onColorSample: nil,
                        compareEnabled: false,
                        comparePixelBuffer: nil,
                        compareSplitX: 0.5,
                        captureCompareRequest: $captureRequest,
                        onCompareCapture: nil,
                        falseColorEnabled: false,
                        onTransformUpdate: nil,
                        autoToneMap: false
                    )
                } else {
                    CellPlaceholder(isDragTargeted: isDragTargeted)
                }

                // ── 파일명 레이블 ────────────────────────────────────
                if !slot.filename.isEmpty {
                    Text(slot.filename)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                        .allowsHitTesting(false)
                }

                // ── 활성 셀 테두리 ───────────────────────────────────
                if isActive {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .allowsHitTesting(false)
                }

                // ── 드래그 오버레이 ──────────────────────────────────
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.accentColor,
                                style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .background(Color.accentColor.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted, perform: handleDrop)
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        else { return false }

        _ = provider.loadDataRepresentation(
            forTypeIdentifier: UTType.fileURL.identifier
        ) { data, _ in
            guard let data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else { return }
            Task { @MainActor in onDrop(url) }
        }
        return true
    }
}

// MARK: - Cell Placeholder

private struct CellPlaceholder: View {
    let isDragTargeted: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 10) {
                Image(systemName: isDragTargeted ? "arrow.down.doc.fill" : "plus.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(isDragTargeted ? Color.accentColor : Color.white.opacity(0.18))
                Text("Drop a clip here")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(isDragTargeted ? 0.6 : 0.2))
            }
        }
    }
}
