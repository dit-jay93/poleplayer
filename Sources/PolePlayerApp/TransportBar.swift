import SwiftUI

import PlayerCore

struct TransportBar: View {
    @ObservedObject var player: PlayerController
    let onPlayPause: () -> Void
    let onStop: () -> Void
    let onStepBack: () -> Void
    let onStepForward: () -> Void
    let audioLevels: AudioMeterMonitor.Levels

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onStepBack) {
                Image(systemName: "backward.frame")
            }
            .buttonStyle(.bordered)

            Button(action: onPlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderedProminent)

            Button(action: onStop) {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.bordered)

            Button(action: onStepForward) {
                Image(systemName: "forward.frame")
            }
            .buttonStyle(.bordered)

            Button(action: player.toggleLooping) {
                Image(systemName: "repeat")
                    .foregroundStyle(player.isLooping ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.bordered)

            Divider()
                .frame(height: 20)

            Button(action: player.toggleMute) {
                Image(systemName: player.isMuted ? "speaker.slash.fill" : volumeIcon)
            }
            .buttonStyle(.bordered)

            Slider(value: $player.volume, in: 0...1)
                .frame(width: 90)
                .disabled(player.isMuted)

            // E: 오디오 미터
            AudioMeterView(levels: audioLevels)
                .opacity(player.hasVideo ? 1 : 0.3)

            Spacer()
            Text("JKL  ·  ← →  ·  Space  ·  I/O/U/P  ·  H  ·  F/G/1  ·  V")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondaryText.opacity(0.4))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(AppFont.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var volumeIcon: String {
        if player.volume == 0 { return "speaker.fill" }
        if player.volume < 0.4 { return "speaker.wave.1.fill" }
        if player.volume < 0.75 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
