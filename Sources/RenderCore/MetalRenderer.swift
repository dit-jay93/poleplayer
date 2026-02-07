import AppKit
import Metal
import MetalKit
import CoreVideo

final class MetalRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private var fallbackTexture: MTLTexture?

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
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        } else if let fallbackTexture {
            encoder.setFragmentTexture(fallbackTexture, index: 0)
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

    fragment float4 fragment_main(VertexOut in [[stage_in]], texture2d<float> colorTexture [[texture(0)]]) {
        constexpr sampler textureSampler (mag_filter::linear, min_filter::linear);
        return colorTexture.sample(textureSampler, in.texCoord);
    }
    """
}
