import SwiftUI

import PlayerCore

struct TransportBar: View {
    @ObservedObject var player: PlayerController
    let onPlayPause: () -> Void
    let onStepBack: () -> Void
    let onStepForward: () -> Void

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

            Button(action: onStepForward) {
                Image(systemName: "forward.frame")
            }
            .buttonStyle(.bordered)

            Spacer()
            Text("JKL / ← → / Space")
                .font(AppFont.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .font(AppFont.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.transportBackground)
    }
}
