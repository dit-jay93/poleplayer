import AppKit
import Metal
import MetalKit
import CoreVideo
import os

public enum ZoomCommand {
    case fit
    case fill
    case pixelPerfect
}

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

    // Zoom / pan state — lock으로 메인 스레드 ↔ 렌더 스레드 경쟁 상태 방지
    private struct ZoomState { var scale: Float = 1.0; var offset: SIMD2<Float> = .zero }
    private let zoomLock = OSAllocatedUnfairLock<ZoomState>(initialState: ZoomState())
    private var userScale: Float {
        get { zoomLock.withLock { $0.scale } }
        set { zoomLock.withLock { $0.scale = newValue } }
    }
    private var userOffset: SIMD2<Float> {
        get { zoomLock.withLock { $0.offset } }
        set { zoomLock.withLock { $0.offset = newValue } }
    }
    private var videoAspect: Float = 1.0
    private var videoSize: CGSize = CGSize(width: 1, height: 1)
    private var lastDragPoint: NSPoint?
    public var isInteractionEnabled: Bool = true

    // EDR (Extended Dynamic Range)
    private var edrConfigured = false
    public var edrHeadroom: Float {
        Float(window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1.0)
    }

    // Scopes
    public var onHistogram: ((HistogramData) -> Void)?
    public var onWaveform: ((WaveformData) -> Void)?
    public var onVectorscope: ((VectorscopeData) -> Void)?
    private var lastScopeTime: CFTimeInterval = 0

    // Pixel sampler
    public var onColorSample: ((PixelColor?) -> Void)?
    public private(set) var lastPixelBuffer: CVPixelBuffer?

    // Transform 변경 콜백 (어노테이션 좌표 역변환용)
    public var onTransformUpdate: ((SIMD2<Float>, SIMD2<Float>) -> Void)?

    // A/B compare
    public var compareEnabled: Bool = false
    public var comparePixelBuffer: CVPixelBuffer?
    public var compareSplitX: Float = 0.5
    // C: False Color
    public var falseColorEnabled: Bool = false

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
        mtkView.colorPixelFormat = .rgba16Float
        mtkView.delegate = self
        mtkView.autoresizingMask = [.width, .height]
        addSubview(mtkView)

        let capture = EventCaptureView(frame: bounds)
        capture.autoresizingMask = [.width, .height]
        capture.onScroll = { [weak self] event in
            guard self?.isInteractionEnabled == true else { return }
            self?.handleScrollWheel(event)
        }
        capture.onMouseDown = { [weak self] event in
            guard self?.isInteractionEnabled == true else { return }
            self?.lastDragPoint = event.locationInWindow
        }
        capture.onMouseDragged = { [weak self] event in
            guard self?.isInteractionEnabled == true else { return }
            self?.handleMouseDragged(event)
        }
        capture.onDoubleClick = { [weak self] _ in
            guard self?.isInteractionEnabled == true else { return }
            self?.resetZoom()
        }
        capture.onMouseMoved = { [weak self] event in
            self?.handleMouseMoved(event)
        }
        capture.onMouseExited = { [weak self] in
            self?.onColorSample?(nil)
        }
        addSubview(capture)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layout() {
        super.layout()
        mtkView.frame = bounds
        configureEDROnce()
        notifyTransformUpdate()
    }

    private func configureEDROnce() {
        guard !edrConfigured,
              let metalLayer = mtkView.layer as? CAMetalLayer else { return }
        metalLayer.wantsExtendedDynamicRangeContent = true
        if let cs = CGColorSpace(name: CGColorSpace.extendedSRGB) {
            metalLayer.colorspace = cs
        }
        edrConfigured = true
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

    public func updateHDRMode(_ mode: String, autoToneMap: Bool) {
        renderer?.updateHDRMode(mode, autoToneMap: autoToneMap)
    }

    public func updateVideoAspect(_ aspect: Float) {
        videoAspect = aspect > 0 ? aspect : 1.0
    }

    public func updateVideoSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard videoSize != size else { return }   // 같은 크기면 루프 방지
        videoSize = size
        videoAspect = Float(size.width / size.height)
        notifyTransformUpdate()
    }

    public func resetZoom() {
        zoomLock.withLock { $0 = ZoomState() }
        notifyTransformUpdate()
    }

    public func setZoomToFill() {
        let drawableSize = mtkView.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { resetZoom(); return }
        let viewAspect = Float(drawableSize.width / drawableSize.height)
        var fitScaleX: Float = 1.0
        var fitScaleY: Float = 1.0
        if videoAspect > viewAspect {
            fitScaleY = viewAspect / videoAspect
        } else if videoAspect < viewAspect {
            fitScaleX = videoAspect / viewAspect
        }
        // Scale up until the short dimension fills the view (no black bars)
        userScale = 1.0 / min(fitScaleX, fitScaleY)
        userOffset = SIMD2<Float>(0, 0)
        notifyTransformUpdate()
    }

    public func setZoomToPixelPerfect() {
        let drawableSize = mtkView.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0 else { resetZoom(); return }
        // Scale so that 1 video pixel maps to 1 drawable (Retina) pixel
        let scaleForWidth = Float(videoSize.width / drawableSize.width)
        let scaleForHeight = Float(videoSize.height / drawableSize.height)
        userScale = max(scaleForWidth, scaleForHeight)
        userOffset = SIMD2<Float>(0, 0)
        notifyTransformUpdate()
    }

    public func applyZoomCommand(_ command: ZoomCommand) {
        switch command {
        case .fit: resetZoom()
        case .fill: setZoomToFill()
        case .pixelPerfect: setZoomToPixelPerfect()
        }
    }

    // MARK: - Transform Notification

    private func notifyTransformUpdate() {
        let (scale, offset) = computeTransform(drawableSize: mtkView.drawableSize)
        onTransformUpdate?(scale, offset)
    }

    // MARK: - Pixel Sampler

    private func handleMouseMoved(_ event: NSEvent) {
        guard let callback = onColorSample else { return }
        let pt = convert(event.locationInWindow, from: nil)
        callback(sampleColor(at: pt))
    }

    private func sampleColor(at viewPoint: NSPoint) -> PixelColor? {
        guard let buf = lastPixelBuffer else { return nil }
        let drawableSize = mtkView.drawableSize
        guard drawableSize.width > 0, drawableSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return nil }

        let (scale, offset) = computeTransform(drawableSize: drawableSize)

        // View point (AppKit: bottom-left origin) → NDC
        let ndcX = Float(viewPoint.x / bounds.width)  * 2 - 1
        let ndcY = Float(viewPoint.y / bounds.height) * 2 - 1

        // NDC → video UV ([0,1], top-left origin)
        let u =        (ndcX - offset.x) / (2 * scale.x) + 0.5
        let v = 1.0 - ((ndcY - offset.y) / (2 * scale.y) + 0.5)
        guard u >= 0, u <= 1, v >= 0, v <= 1 else { return nil }

        let w = CVPixelBufferGetWidth(buf)
        let h = CVPixelBufferGetHeight(buf)
        let px = min(Int(u * Float(w)), w - 1)
        let py = min(Int(v * Float(h)), h - 1)
        return PixelSampler.sample(from: buf, x: px, y: py)
    }

    // MARK: - Zoom / Pan

    private func computeTransform(drawableSize: CGSize) -> (SIMD2<Float>, SIMD2<Float>) {
        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return (SIMD2<Float>(1, 1), SIMD2<Float>(0, 0))
        }
        let viewAspect = Float(drawableSize.width / drawableSize.height)
        var fitScaleX: Float = 1.0
        var fitScaleY: Float = 1.0
        if videoAspect > viewAspect {
            fitScaleY = viewAspect / videoAspect
        } else if videoAspect < viewAspect {
            fitScaleX = videoAspect / viewAspect
        }
        // lock을 한 번만 잡아 렌더 스레드와의 경쟁 상태 방지
        let (scale, offset) = zoomLock.withLock { ($0.scale, $0.offset) }
        return (
            SIMD2<Float>(fitScaleX * scale, fitScaleY * scale),
            offset
        )
    }

    private func handleScrollWheel(_ event: NSEvent) {
        if event.magnification != 0 {
            let factor = Float(1.0 + event.magnification)
            guard factor > 0 else { return }
            let pt = convert(event.locationInWindow, from: nil)
            zoomBy(factor, centeredAt: pt)
        } else if event.hasPreciseScrollingDeltas {
            // Trackpad two-finger scroll → pan
            let ndcDX = Float(event.scrollingDeltaX) * 2.0 / Float(max(bounds.width, 1))
            let ndcDY = Float(event.scrollingDeltaY) * 2.0 / Float(max(bounds.height, 1))
            userOffset += SIMD2<Float>(ndcDX, -ndcDY)
        } else {
            // Mouse scroll wheel → zoom
            let delta = event.deltaY
            guard delta != 0 else { return }
            let factor = Float(pow(1.1, Double(delta)))
            let pt = convert(event.locationInWindow, from: nil)
            zoomBy(factor, centeredAt: pt)
        }
        notifyTransformUpdate()
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard let last = lastDragPoint else { return }
        let current = event.locationInWindow
        let dx = Float(current.x - last.x) * 2.0 / Float(max(bounds.width, 1))
        let dy = Float(current.y - last.y) * 2.0 / Float(max(bounds.height, 1))
        userOffset += SIMD2<Float>(dx, dy)
        lastDragPoint = current
        notifyTransformUpdate()
    }

    private func zoomBy(_ factor: Float, centeredAt viewPoint: NSPoint) {
        let ndcX = Float(viewPoint.x / max(bounds.width, 1)) * 2 - 1
        let ndcY = Float(viewPoint.y / max(bounds.height, 1)) * 2 - 1
        let cx = SIMD2<Float>(ndcX, ndcY)
        zoomLock.withLock { state in
            state.offset = cx + (state.offset - cx) * factor
            state.scale  = max(0.1, min(50.0, state.scale * factor))
        }
    }

    // MARK: - Overlay

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

// MARK: - MTKViewDelegate

extension MetalVideoView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        notifyTransformUpdate()
    }

    public func draw(in view: MTKView) {
        let hostTime = CACurrentMediaTime()
        let pixelBuffer = frameProvider?(hostTime)
        // nil이면 lastPixelBuffer 유지 → pause 시 last-frame hold (체커보드 방지)
        if let pixelBuffer { lastPixelBuffer = pixelBuffer }
        updateOverlayIfNeeded(drawableSize: view.drawableSize)
        let (scale, offset) = computeTransform(drawableSize: view.drawableSize)
        renderer?.updateTransform(scale: scale, offset: offset)
        renderer?.updateCompareFrame(
            pixelBuffer: compareEnabled ? comparePixelBuffer : nil,
            splitX: compareSplitX,
            enabled: compareEnabled
        )
        renderer?.updateFalseColor(enabled: falseColorEnabled)
        renderer?.draw(pixelBuffer: pixelBuffer ?? lastPixelBuffer, in: view)

        // Scopes: 새 프레임이 있을 때만, 최대 ~10 fps
        // (서브샘플링으로 4K에서도 5ms 이하 유지)
        if let buf = pixelBuffer,
           (onHistogram != nil || onWaveform != nil || onVectorscope != nil),
           hostTime - lastScopeTime > 0.1 {
            lastScopeTime = hostTime
            if let cb = onHistogram, let data = HistogramComputer.compute(from: buf) {
                cb(data)
            }
            if let cb = onWaveform, let data = WaveformComputer.compute(from: buf) {
                cb(data)
            }
            if let cb = onVectorscope, let data = VectorscopeComputer.compute(from: buf) {
                cb(data)
            }
        }
    }
}

// MARK: - Event Capture

private final class EventCaptureView: NSView {
    var onScroll: ((NSEvent) -> Void)?
    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onDoubleClick: ((NSEvent) -> Void)?
    var onMouseMoved: ((NSEvent) -> Void)?
    var onMouseExited: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        ))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClick?(event)
        } else {
            onMouseDown?(event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event)
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseMoved?(event)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    override func draw(_ dirtyRect: NSRect) {
        // Transparent overlay — no drawing
    }
}
