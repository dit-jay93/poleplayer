import AppKit
import Metal
import MetalKit
import CoreVideo

public final class MetalVideoView: NSView {
    public typealias FrameProvider = (CFTimeInterval) -> CVPixelBuffer?
    public typealias HUDProvider = () -> HUDOverlayData?

    private let mtkView: MTKView
    private let renderer: MetalRenderer?
    private var frameProvider: FrameProvider?
    private var hudProvider: HUDProvider?
    private let hudRenderer = HUDOverlayRenderer()
    private var lastHUDData: HUDOverlayData?
    private var lastHUDSize: CGSize = .zero

    public init(frame: NSRect, frameProvider: FrameProvider?, hudProvider: HUDProvider? = nil) {
        let device = MTLCreateSystemDefaultDevice()
        self.mtkView = MTKView(frame: frame, device: device)
        self.renderer = device.flatMap { MetalRenderer(device: $0) }
        self.frameProvider = frameProvider
        self.hudProvider = hudProvider

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

    public func updateHUDProvider(_ provider: HUDProvider?) {
        hudProvider = provider
    }

    public func updateLUT(cube: LUTCube?, intensity: Float, enabled: Bool) {
        renderer?.updateLUT(cube: cube, intensity: intensity, enabled: enabled)
    }

    private func updateHUDIfNeeded(drawableSize: CGSize) {
        guard let provider = hudProvider else {
            renderer?.updateOverlay(image: nil, enabled: false)
            return
        }
        guard let data = provider() else {
            renderer?.updateOverlay(image: nil, enabled: false)
            return
        }
        if data != lastHUDData || drawableSize != lastHUDSize {
            let image = hudRenderer.renderImage(size: drawableSize, data: data)
            renderer?.updateOverlay(image: image, enabled: image != nil)
            lastHUDData = data
            lastHUDSize = drawableSize
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
        updateHUDIfNeeded(drawableSize: view.drawableSize)
        renderer?.draw(pixelBuffer: pixelBuffer, in: view)
    }
}
