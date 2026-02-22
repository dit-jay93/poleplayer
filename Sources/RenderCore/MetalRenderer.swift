import AppKit
import Metal
import MetalKit
import CoreVideo

final class MetalRenderer {
    struct TransformParams {
        var scale: SIMD2<Float>
        var offset: SIMD2<Float>
    }

    struct LUTParams {
        var domainMin: SIMD4<Float>
        var domainMax: SIMD4<Float>
        var intensity: Float
        var lutEnabled: Float
        var overlayEnabled: Float
        var falseColorEnabled: Float = 0  // C: false color
        var lutDimension: Float = 0       // 0 = 3D, 1 = 1D
        var autoToneMap: Float = 0        // 0 = off, 1 = on
        var hdrMode: Float = 0            // 0 = SDR, 1 = HLG, 2 = PQ
        var _pad: Float = 0               // align to 64 bytes
    }

    struct CompareParams {
        var wipeSplit: Float = 0.5
        var compareEnabled: Float = 0.0
        var drawableWidth: Float = 0.0
        var padding: Float = 0
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private var fallbackTexture: MTLTexture?
    private var lutTexture: MTLTexture?
    private var identityLUT: MTLTexture?
    private var overlayTexture: MTLTexture?
    private var overlayTextureSize: CGSize = .zero
    private var emptyOverlayTexture: MTLTexture?
    private var _comparePixelBuffer: CVPixelBuffer?
    private var compareParams = CompareParams()
    private var transformParams = TransformParams(
        scale: SIMD2<Float>(1, 1),
        offset: SIMD2<Float>(0, 0)
    )
    private var lutParams = LUTParams(
        domainMin: SIMD4<Float>(0, 0, 0, 0),
        domainMax: SIMD4<Float>(1, 1, 1, 0),
        intensity: 1.0,
        lutEnabled: 0.0,
        overlayEnabled: 0.0
    )

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        guard let library = try? device.makeLibrary(source: MetalRenderer.shaderSource, options: nil) else {
            return nil
        }
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            return nil
        }

        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        fallbackTexture = makeFallbackTexture(device: device)
        identityLUT = makeIdentityLUTTexture(device: device, size: 2)
        lutTexture = identityLUT
        emptyOverlayTexture = makeEmptyOverlayTexture(device: device)
    }

    @MainActor
    func draw(pixelBuffer: CVPixelBuffer?, in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        compareParams.drawableWidth = Float(view.drawableSize.width)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBytes(&transformParams, length: MemoryLayout<TransformParams>.stride, index: 0)

        let mainTex = pixelBuffer.flatMap { makeTexture(from: $0) } ?? fallbackTexture
        let compareTex = _comparePixelBuffer.flatMap { makeTexture(from: $0) } ?? emptyOverlayTexture
        encoder.setFragmentTexture(mainTex, index: 0)
        encoder.setFragmentTexture(lutTexture ?? identityLUT, index: 1)
        encoder.setFragmentTexture(overlayTexture ?? emptyOverlayTexture, index: 2)
        encoder.setFragmentTexture(compareTex, index: 3)
        encoder.setFragmentBytes(&lutParams, length: MemoryLayout<LUTParams>.stride, index: 0)
        encoder.setFragmentBytes(&compareParams, length: MemoryLayout<CompareParams>.stride, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func updateCompareFrame(pixelBuffer: CVPixelBuffer?, splitX: Float, enabled: Bool) {
        compareParams.compareEnabled = enabled ? 1.0 : 0.0
        compareParams.wipeSplit = splitX
        _comparePixelBuffer = enabled ? pixelBuffer : nil
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let cache = textureCache else { return nil }

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess, let cvTexture else { return nil }
        return CVMetalTextureGetTexture(cvTexture)
    }

    private func makeFallbackTexture(device: MTLDevice) -> MTLTexture? {
        let size = 64
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        var data = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0..<size {
            for x in 0..<size {
                let index = (y * size + x) * 4
                let isEven = ((x / 8) + (y / 8)) % 2 == 0
                data[index + 0] = isEven ? 40 : 200   // B
                data[index + 1] = isEven ? 200 : 40   // G
                data[index + 2] = 40                  // R
                data[index + 3] = 255                 // A
            }
        }

        data.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, size, size),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: size * 4
            )
        }

        return texture
    }

    private func makeEmptyOverlayTexture(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let transparent: [UInt8] = [0, 0, 0, 0]
        transparent.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: 4
            )
        }
        return texture
    }

    private func makeIdentityLUTTexture(device: MTLDevice, size: Int) -> MTLTexture? {
        guard size > 1 else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = MTLPixelFormat.rgba16Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.mipmapLevelCount = 1
        descriptor.usage = MTLTextureUsage.shaderRead
        descriptor.storageMode = MTLStorageMode.shared

        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        var data = [Float16](repeating: 0, count: size * size * size * 4)
        var index = 0
        for r in 0..<size {
            for g in 0..<size {
                for b in 0..<size {
                    let rf = Float(r) / Float(size - 1)
                    let gf = Float(g) / Float(size - 1)
                    let bf = Float(b) / Float(size - 1)
                    data[index + 0] = Float16(rf)
                    data[index + 1] = Float16(gf)
                    data[index + 2] = Float16(bf)
                    data[index + 3] = Float16(1.0)
                    index += 4
                }
            }
        }

        let bytesPerRow = size * 4 * MemoryLayout<Float16>.size
        let bytesPerImage = size * size * 4 * MemoryLayout<Float16>.size
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                texture.replace(
                    region: MTLRegionMake3D(0, 0, 0, size, size, size),
                    mipmapLevel: 0,
                    slice: 0,
                    withBytes: baseAddress,
                    bytesPerRow: bytesPerRow,
                    bytesPerImage: bytesPerImage
                )
            }
        }

        return texture
    }

    private func makeLUTTexture(from cube: LUTCube) -> MTLTexture? {
        let size = cube.size
        guard size > 1 else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = MTLPixelFormat.rgba16Float
        descriptor.width = size
        descriptor.height = size
        descriptor.depth = size
        descriptor.mipmapLevelCount = 1
        descriptor.usage = MTLTextureUsage.shaderRead
        descriptor.storageMode = MTLStorageMode.shared

        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        var data = [Float16](repeating: 0, count: size * size * size * 4)
        for i in 0..<cube.values.count {
            let base = i * 4
            let value = cube.values[i]
            data[base + 0] = Float16(value.x)
            data[base + 1] = Float16(value.y)
            data[base + 2] = Float16(value.z)
            data[base + 3] = Float16(1.0)
        }

        let bytesPerRow = size * 4 * MemoryLayout<Float16>.size
        let bytesPerImage = size * size * 4 * MemoryLayout<Float16>.size
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                texture.replace(
                    region: MTLRegionMake3D(0, 0, 0, size, size, size),
                    mipmapLevel: 0,
                    slice: 0,
                    withBytes: baseAddress,
                    bytesPerRow: bytesPerRow,
                    bytesPerImage: bytesPerImage
                )
            }
        }

        return texture
    }

    private func makeLUT1DTexture(from cube: LUTCube, size: Int) -> MTLTexture? {
        guard size > 0 else { return nil }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = size
        descriptor.height = 1
        descriptor.depth = 1
        descriptor.mipmapLevelCount = 1
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }

        var data = [Float16](repeating: 0, count: size * 4)
        for i in 0..<min(cube.values.count, size) {
            let base = i * 4
            data[base + 0] = Float16(cube.values[i].x)
            data[base + 1] = Float16(cube.values[i].y)
            data[base + 2] = Float16(cube.values[i].z)
            data[base + 3] = Float16(1.0)
        }

        let bytesPerRow = size * 4 * MemoryLayout<Float16>.size
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                texture.replace(
                    region: MTLRegionMake3D(0, 0, 0, size, 1, 1),
                    mipmapLevel: 0,
                    slice: 0,
                    withBytes: baseAddress,
                    bytesPerRow: bytesPerRow,
                    bytesPerImage: bytesPerRow
                )
            }
        }

        return texture
    }

    func updateTransform(scale: SIMD2<Float>, offset: SIMD2<Float>) {
        transformParams = TransformParams(scale: scale, offset: offset)
    }

    func updateFalseColor(enabled: Bool) {
        lutParams.falseColorEnabled = enabled ? 1.0 : 0.0
    }

    func updateLUT(cube: LUTCube?, intensity: Float, enabled: Bool) {
        if let cube {
            switch cube.dimension {
            case .lut3D:
                lutTexture = makeLUTTexture(from: cube) ?? identityLUT
                lutParams.lutDimension = 0
            case .lut1D(let s):
                lutTexture = makeLUT1DTexture(from: cube, size: s) ?? identityLUT
                lutParams.lutDimension = 1
            }
            lutParams.domainMin = SIMD4<Float>(cube.domainMin.x, cube.domainMin.y, cube.domainMin.z, 0)
            lutParams.domainMax = SIMD4<Float>(cube.domainMax.x, cube.domainMax.y, cube.domainMax.z, 0)
            lutParams.lutEnabled = enabled ? 1.0 : 0.0
        } else {
            lutTexture = identityLUT
            lutParams.domainMin = SIMD4<Float>(0, 0, 0, 0)
            lutParams.domainMax = SIMD4<Float>(1, 1, 1, 0)
            lutParams.lutEnabled = 0.0
            lutParams.lutDimension = 0
        }
        lutParams.intensity = max(0, min(intensity, 1.0))
    }

    func updateHDRMode(_ mode: String, autoToneMap: Bool) {
        switch mode {
        case "HLG":   lutParams.hdrMode = 1
        case "HDR10": lutParams.hdrMode = 2
        default:      lutParams.hdrMode = 0
        }
        lutParams.autoToneMap = autoToneMap ? 1.0 : 0.0
    }

    func updateOverlay(image: CGImage?, enabled: Bool) {
        lutParams.overlayEnabled = enabled ? 1.0 : 0.0
        guard enabled, let image else {
            overlayTexture = nil
            return
        }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return }

        if overlayTexture == nil || overlayTextureSize != CGSize(width: width, height: height) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            overlayTexture = device.makeTexture(descriptor: descriptor)
            overlayTextureSize = CGSize(width: width, height: height)
        }

        guard let overlayTexture else { return }

        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        data.withUnsafeMutableBytes { bytes in
            if let base = bytes.baseAddress,
               let context = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
               ) {
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                context.clear(rect)
                context.draw(image, in: rect)
            }
        }

        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                overlayTexture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: baseAddress,
                    bytesPerRow: bytesPerRow
                )
            }
        }
    }
}

private extension MetalRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    struct TransformParams {
        float2 scale;
        float2 offset;
    };

    vertex VertexOut vertex_main(
        uint vertexID [[vertex_id]],
        constant TransformParams& transform [[buffer(0)]]
    ) {
        float2 positions[4] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2( 1.0,  1.0)
        };

        float2 texCoords[4] = {
            float2(0.0, 1.0),
            float2(1.0, 1.0),
            float2(0.0, 0.0),
            float2(1.0, 0.0)
        };

        VertexOut out;
        out.position = float4(positions[vertexID] * transform.scale + transform.offset, 0.0, 1.0);
        out.texCoord = texCoords[vertexID];
        return out;
    }

    struct LUTParams {
        float4 domainMin;
        float4 domainMax;
        float intensity;
        float lutEnabled;
        float overlayEnabled;
        float falseColorEnabled;
        float lutDimension;
        float autoToneMap;
        float hdrMode;
        float _pad;
    };

    float3 applyFalseColor(float luma) {
        if (luma < 0.020) return float3(0.12, 0.06, 0.40);  // 딥 퍼플: 블랙 클립
        if (luma < 0.100) return float3(0.15, 0.25, 0.80);  // 블루: 언더
        if (luma < 0.180) return float3(0.30, 0.55, 0.90);  // 스카이: 다크
        if (luma < 0.450) return float3(0.20, 0.70, 0.30);  // 그린: 미드로우
        if (luma < 0.700) return float3(0.82, 0.82, 0.82);  // 그레이: 정상
        if (luma < 0.850) return float3(0.95, 0.88, 0.20);  // 옐로우: 브라이트
        if (luma < 0.950) return float3(1.00, 0.55, 0.05);  // 오렌지: 니어클립
        return float3(1.00, 0.08, 0.08);                    // 레드: 클립
    }

    struct CompareParams {
        float wipeSplit;
        float compareEnabled;
        float drawableWidth;
        float padding;
    };

    fragment float4 fragment_main(
        VertexOut in [[stage_in]],
        texture2d<float> colorTexture  [[texture(0)]],
        texture3d<float> lutTexture    [[texture(1)]],
        texture2d<float> overlayTexture[[texture(2)]],
        texture2d<float> compareTexture[[texture(3)]],
        constant LUTParams&    params  [[buffer(0)]],
        constant CompareParams& compare[[buffer(1)]]
    ) {
        constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

        // A/B wipe: pixels left of split sample the A (compare) frame,
        // pixels right sample the B (current) frame. Both get LUT applied.
        float4 color;
        if (compare.compareEnabled >= 0.5 && compare.drawableWidth > 0.0) {
            float screenFrac = in.position.x / compare.drawableWidth;
            if (screenFrac < compare.wipeSplit) {
                color = compareTexture.sample(textureSampler, in.texCoord);
            } else {
                color = colorTexture.sample(textureSampler, in.texCoord);
            }
        } else {
            color = colorTexture.sample(textureSampler, in.texCoord);
        }

        float3 outputColor = color.rgb;
        if (params.lutEnabled >= 0.5) {
            float3 domainMin = params.domainMin.xyz;
            float3 domainMax = params.domainMax.xyz;

            constexpr sampler lutSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
            float3 lutColor;

            if (params.lutDimension < 0.5) {
                // 3D LUT
                float3 denom = max(domainMax - domainMin, float3(1e-6));
                float3 normalized = clamp((color.rgb - domainMin) / denom, 0.0, 1.0);
                lutColor = lutTexture.sample(lutSampler, normalized).rgb;
            } else {
                // 1D LUT: luma-based lookup in Nx1x1 texture
                float luma = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
                luma = clamp((luma - domainMin.x) / max(domainMax.x - domainMin.x, 1e-6), 0.0, 1.0);
                lutColor = lutTexture.sample(lutSampler, float3(luma, 0.5, 0.5)).rgb;
            }
            outputColor = mix(color.rgb, lutColor, params.intensity);
        }

        // C: False Color — LUT 적용 후 적용
        if (params.falseColorEnabled >= 0.5) {
            float luma = dot(outputColor, float3(0.2126, 0.7152, 0.0722));
            outputColor = applyFalseColor(luma);
        }

        // HDR → SDR Reinhard tone-map
        if (params.autoToneMap >= 0.5) {
            outputColor = outputColor / (1.0 + outputColor);
            outputColor = pow(max(outputColor, 0.0), float3(1.0 / 2.2));
        }

        float4 output = float4(outputColor, color.a);
        if (params.overlayEnabled >= 0.5) {
            constexpr sampler overlaySampler(mag_filter::linear, min_filter::linear);
            float4 overlay = overlayTexture.sample(overlaySampler, in.texCoord);
            output = mix(output, overlay, overlay.a);
        }

        return output;
    }
    """
}
