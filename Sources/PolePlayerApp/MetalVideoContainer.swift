import RenderCore
import PlayerCore
import SwiftUI

struct MetalVideoContainer: NSViewRepresentable {
    let player: PlayerController
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double

    func makeNSView(context: Context) -> MetalVideoView {
        let view = MetalVideoView(frame: .zero, frameProvider: { hostTime in
            Task { @MainActor in
                player.recordRenderTick(hostTime: hostTime)
            }
            return player.copyPixelBuffer(hostTime: hostTime)
        }, hudProvider: {
            guard player.hasVideo else { return nil }
            return HUDOverlayData(
                timecode: player.timecode,
                frameIndex: player.frameIndex,
                fps: player.fps,
                resolution: player.resolution
            )
        })
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
        nsView.updateHUDProvider {
            guard player.hasVideo else { return nil }
            return HUDOverlayData(
                timecode: player.timecode,
                frameIndex: player.frameIndex,
                fps: player.fps,
                resolution: player.resolution
            )
        }
        nsView.updateLUT(cube: lutCube, intensity: Float(lutIntensity), enabled: lutEnabled)
    }
}
