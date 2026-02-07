import RenderCore
import PlayerCore
import SwiftUI

struct MetalVideoContainer: NSViewRepresentable {
    let player: PlayerController

    func makeNSView(context: Context) -> MetalVideoView {
        MetalVideoView(frame: .zero) { hostTime in
            player.copyPixelBuffer(hostTime: hostTime)
        }
    }

    func updateNSView(_ nsView: MetalVideoView, context: Context) {
        nsView.updateFrameProvider { hostTime in
            player.copyPixelBuffer(hostTime: hostTime)
        }
    }
}
