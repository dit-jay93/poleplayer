import AppKit
import Metal
import MetalKit
import CoreVideo

final class MetalRenderer {
    struct LUTParams {
        var domainMin: SIMD4<Float>
        var domainMax: SIMD4<Float>
        var intensity: Float
        var lutEnabled: Float
        var overlayEnabled: Float
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
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

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

        encoder.setRenderPipelineState(pipelineState)

        if let pixelBuffer,
           let texture = makeTexture(from: pixelBuffer) {
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentTexture(lutTexture ?? identityLUT, index: 1)
            encoder.setFragmentTexture(overlayTexture ?? emptyOverlayTexture, index: 2)
            encoder.setFragmentBytes(&lutParams, length: MemoryLayout<LUTParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else if let fallbackTexture {
            encoder.setFragmentTexture(fallbackTexture, index: 0)
            encoder.setFragmentTexture(lutTexture ?? identityLUT, index: 1)
            encoder.setFragmentTexture(overlayTexture ?? emptyOverlayTexture, index: 2)
            encoder.setFragmentBytes(&lutParams, length: MemoryLayout<LUTParams>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
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

    func updateLUT(cube: LUTCube?, intensity: Float, enabled: Bool) {
        if let cube {
            lutTexture = makeLUTTexture(from: cube) ?? identityLUT
            lutParams.domainMin = SIMD4<Float>(cube.domainMin.x, cube.domainMin.y, cube.domainMin.z, 0)
            lutParams.domainMax = SIMD4<Float>(cube.domainMax.x, cube.domainMax.y, cube.domainMax.z, 0)
            lutParams.lutEnabled = enabled ? 1.0 : 0.0
        } else {
            lutTexture = identityLUT
            lutParams.domainMin = SIMD4<Float>(0, 0, 0, 0)
            lutParams.domainMax = SIMD4<Float>(1, 1, 1, 0)
            lutParams.lutEnabled = 0.0
        }
        lutParams.intensity = max(0, min(intensity, 1.0))
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

    vertex VertexOut vertex_main(uint vertexID [[vertex_id]]) {
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
        out.position = float4(positions[vertexID], 0.0, 1.0);
        out.texCoord = texCoords[vertexID];
        return out;
    }

    struct LUTParams {
        float4 domainMin;
        float4 domainMax;
        float intensity;
        float lutEnabled;
        float overlayEnabled;
        float padding;
    };

    fragment float4 fragment_main(
        VertexOut in [[stage_in]],
        texture2d<float> colorTexture [[texture(0)]],
        texture3d<float> lutTexture [[texture(1)]],
        texture2d<float> overlayTexture [[texture(2)]],
        constant LUTParams& params [[buffer(0)]]
    ) {
        constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
        float4 color = colorTexture.sample(textureSampler, in.texCoord);
        float3 outputColor = color.rgb;
        if (params.lutEnabled >= 0.5) {
            float3 domainMin = params.domainMin.xyz;
            float3 domainMax = params.domainMax.xyz;
            float3 denom = max(domainMax - domainMin, float3(1e-6));
            float3 normalized = clamp((color.rgb - domainMin) / denom, 0.0, 1.0);

            constexpr sampler lutSampler (mag_filter::linear, min_filter::linear, address::clamp_to_edge);
            float3 lutColor = lutTexture.sample(lutSampler, normalized).rgb;
            outputColor = mix(color.rgb, lutColor, params.intensity);
        }

        float4 output = float4(outputColor, color.a);
        if (params.overlayEnabled >= 0.5) {
            constexpr sampler overlaySampler (mag_filter::linear, min_filter::linear);
            float4 overlay = overlayTexture.sample(overlaySampler, in.texCoord);
            output = mix(output, overlay, overlay.a);
        }

        return output;
    }
    """
}
