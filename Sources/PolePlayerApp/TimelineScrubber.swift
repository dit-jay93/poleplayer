import PlayerCore
import SwiftUI

/// 타임라인 스크러버 — 재생위치 시각화 + 클릭/드래그 시크 + In/Out 마커
struct TimelineScrubber: View {
    @ObservedObject var player: PlayerController

    @State private var isDragging  = false
    @State private var isHovering  = false

    private let trackH: CGFloat = 3
    private let totalH: CGFloat = 28

    var body: some View {
        VStack(spacing: 2) {
            // ── 썸네일 스트립 ───────────────────────────────────────
            if !player.thumbnails.isEmpty {
                ThumbnailStrip(thumbnails: player.thumbnails)
                    .frame(height: 36)
            }

            // ── 기존 스크러버 ───────────────────────────────────────
            GeometryReader { geo in
                let w   = geo.size.width
                let pos = progressFraction
                let inF = inFraction
                let ouF = outFraction

                ZStack(alignment: .leading) {

                    // ── 트랙 배경 ──────────────────────────────────────────
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: trackH)
                        .frame(maxHeight: .infinity)

                    // ── In/Out 루프 구간 강조 ──────────────────────────────
                    if let i = inF, let o = ouF, o > i {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.22))
                            .frame(width: (o - i) * w, height: trackH)
                            .offset(x: i * w)
                            .frame(maxHeight: .infinity)
                    }

                    // ── 재생 진행 바 ────────────────────────────────────────
                    Capsule()
                        .fill(Color.white.opacity(isHovering || isDragging ? 0.65 : 0.38))
                        .frame(width: max(0, pos * w), height: trackH)
                        .frame(maxHeight: .infinity)
                        .animation(.easeOut(duration: 0.06), value: isHovering)

                    // ── In Point 마커 ───────────────────────────────────────
                    if let i = inF {
                        ScrubMarker(color: Color.accentColor, position: .in)
                            .offset(x: i * w)
                    }

                    // ── Out Point 마커 ──────────────────────────────────────
                    if let o = ouF {
                        ScrubMarker(color: Color(red: 1, green: 0.5, blue: 0.2), position: .out)
                            .offset(x: o * w)
                    }

                    // ── 플레이헤드 ──────────────────────────────────────────
                    if player.hasVideo {
                        let dia: CGFloat = isDragging ? 14 : (isHovering ? 12 : 10)
                        Circle()
                            .fill(Color.white)
                            .frame(width: dia, height: dia)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                            .offset(x: pos * w - dia / 2)
                            .frame(maxHeight: .infinity)
                            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isDragging)
                            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isHovering)
                    }
                }
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDragging = true
                            let frame = frameAt(x: val.location.x, width: w)
                            player.scrubToFrame(frame)
                        }
                        .onEnded { val in
                            isDragging = false
                            let frame = frameAt(x: val.location.x, width: w)
                            player.seek(toFrameIndex: frame)   // 드래그 끝에 정밀 시크
                        }
                )
            }
            .frame(height: totalH)
        }
    }

    // MARK: - Helpers

    private var progressFraction: Double {
        guard player.durationFrames > 0 else { return 0 }
        return Double(player.frameIndex) / Double(player.durationFrames)
    }

    private var inFraction: Double? {
        guard let ip = player.inPointFrame, player.durationFrames > 0 else { return nil }
        return Double(ip) / Double(player.durationFrames)
    }

    private var outFraction: Double? {
        guard let op = player.outPointFrame, player.durationFrames > 0 else { return nil }
        return Double(op) / Double(player.durationFrames)
    }

    private func frameAt(x: CGFloat, width: CGFloat) -> Int {
        let frac = max(0, min(1, x / width))
        return Int(frac * Double(player.durationFrames))
    }
}

// MARK: - 마커 모양

private struct ScrubMarker: View {
    enum Position { case `in`, out }
    let color: Color
    let position: Position

    var body: some View {
        VStack(spacing: 0) {
            // 삼각 헤드
            Triangle(pointingDown: position == .out)
                .fill(color)
                .frame(width: 7, height: 5)
            // 수직선
            Rectangle()
                .fill(color.opacity(0.75))
                .frame(width: 1.5, height: 10)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .offset(x: position == .in ? -1 : -6)
    }
}

private struct Triangle: Shape {
    var pointingDown: Bool = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointingDown {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}

private struct ThumbnailStrip: View {
    let thumbnails: [CGImage]

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(max(1, thumbnails.count))
            HStack(spacing: 0) {
                ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, cgImage in
                    Image(nsImage: NSImage(cgImage: cgImage, size: .zero))
                        .resizable()
                        .scaledToFill()
                        .frame(width: cellW, height: geo.size.height)
                        .clipped()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .allowsHitTesting(false)   // 제스처는 스크러버에서 처리
    }
}
