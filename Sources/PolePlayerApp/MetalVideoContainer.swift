import RenderCore
import PlayerCore
import SwiftUI

struct MetalVideoContainer: NSViewRepresentable {
    let player: PlayerController
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double

    func makeNSView(context: Context) -> MetalVideoView {
        let view = MetalVideoView(frame: .zero) { hostTime in
            Task { @MainActor in
                player.recordRenderTick(hostTime: hostTime)
            }
            return player.copyPixelBuffer(hostTime: hostTime)
        }
        view.updateLUT(cube: lutCube, intensity: Float(lutIntensity), enabled: lutEnabled)
        return view
    }

    func updateNSView(_ nsView: MetalVideoView, context: Context) {
        nsView.updateFrameProvider { hostTime in
            Task { @MainActor in
                player.recordRenderTick(hostTime: hostTime)
            }
            return player.copyPixelBuffer(hostTime: hostTime)
        }
        nsView.updateLUT(cube: lutCube, intensity: Float(lutIntensity), enabled: lutEnabled)
    }
}
