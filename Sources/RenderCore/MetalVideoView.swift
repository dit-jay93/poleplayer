import AppKit
import Metal
import MetalKit
import CoreVideo

public final class MetalVideoView: NSView {
    public typealias FrameProvider = (CFTimeInterval) -> CVPixelBuffer?
    public typealias OverlayProvider = () -> OverlayPayload?

    private let mtkView: MTKView
    private let renderer: MetalRenderer?
    private var frameProvider: FrameProvider?
    private var overlayProvider: OverlayProvider?
    private let overlayComposer = OverlayComposer()
    private var lastOverlayPayload: OverlayPayload?
    private var lastOverlaySize: CGSize = .zero

    public init(frame: NSRect, frameProvider: FrameProvider?, overlayProvider: OverlayProvider? = nil) {
        let device = MTLCreateSystemDefaultDevice()
        self.mtkView = MTKView(frame: frame, device: device)
        self.renderer = device.flatMap { MetalRenderer(device: $0) }
        self.frameProvider = frameProvider
        self.overlayProvider = overlayProvider

        super.init(frame: frame)

        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.delegate = self
        mtkView.autoresizingMask = [.width, .height]
        addSubview(mtkView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layout() {
        super.layout()
        mtkView.frame = bounds
    }

    public func updateFrameProvider(_ provider: FrameProvider?) {
        frameProvider = provider
    }

    public func updateOverlayProvider(_ provider: OverlayProvider?) {
        overlayProvider = provider
    }

    public func updateLUT(cube: LUTCube?, intensity: Float, enabled: Bool) {
        renderer?.updateLUT(cube: cube, intensity: intensity, enabled: enabled)
    }

    private func updateOverlayIfNeeded(drawableSize: CGSize) {
        guard let provider = overlayProvider else {
            renderer?.updateOverlay(image: nil, enabled: false)
            return
        }
        guard let payload = provider() else {
            renderer?.updateOverlay(image: nil, enabled: false)
            return
        }
        if payload != lastOverlayPayload || drawableSize != lastOverlaySize {
            let image = overlayComposer.renderImage(size: drawableSize, payload: payload)
            renderer?.updateOverlay(image: image, enabled: image != nil)
            lastOverlayPayload = payload
            lastOverlaySize = drawableSize
        }
    }
}

extension MetalVideoView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op
    }

    public func draw(in view: MTKView) {
        let hostTime = CACurrentMediaTime()
        let pixelBuffer = frameProvider?(hostTime)
        updateOverlayIfNeeded(drawableSize: view.drawableSize)
        renderer?.draw(pixelBuffer: pixelBuffer, in: view)
    }
}
