import SwiftUI
import PlayerCore

// MARK: - Audio Meter View (E)

/// L/R 채널 세로 바 미터 (RMS + 피크 홀드)
struct AudioMeterView: View {
    let levels: AudioMeterMonitor.Levels

    var body: some View {
        HStack(spacing: 2) {
            MeterBar(rms: levels.left,  peak: levels.peakLeft)
            MeterBar(rms: levels.right, peak: levels.peakRight)
        }
        .frame(width: 14, height: 32)
    }
}

// MARK: - Single Bar

private struct MeterBar: View {
    let rms:  Float
    let peak: Float

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let rmsH  = CGFloat(min(1, max(0, rms)))  * h
            let peakH = CGFloat(min(1, max(0, peak))) * h

            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.07))

                // RMS fill
                Rectangle()
                    .fill(barColor(rms))
                    .frame(height: rmsH)
                    .animation(.linear(duration: 0.05), value: rms)

                // Peak tick
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(height: 1)
                    .offset(y: -peakH + 1)
                    .animation(.linear(duration: 0.1), value: peak)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .frame(width: 6)
    }

    private func barColor(_ level: Float) -> Color {
        if level > 0.9 { return Color(red: 1, green: 0.18, blue: 0.18) }   // 레드: 클리핑
        if level > 0.7 { return Color(red: 1, green: 0.72, blue: 0.10) }   // 옐로우: 하이
        return Color(red: 0.25, green: 0.85, blue: 0.45)                    // 그린: 정상
    }
}
