import AVFoundation
import Accelerate
import CoreMedia
import os

/// MTAudioProcessingTap을 이용해 AVPlayerItem의 실시간 오디오 레벨을 측정합니다.
public final class AudioMeterMonitor: @unchecked Sendable {

    public struct Levels: Sendable {
        public static let silent = Levels(left: 0, right: 0, peakLeft: 0, peakRight: 0)
        public let left:      Float   // 0.0 – 1.0 RMS
        public let right:     Float
        public let peakLeft:  Float   // peak hold
        public let peakRight: Float
    }

    /// 오디오 스레드에서 호출됨. UI 업데이트는 DispatchQueue.main.async 로 감싸서 사용
    public var onLevels: (@Sendable (Levels) -> Void)?

    private let peakDecay: Float = 0.94
    // OSAllocatedUnfairLock: 오디오 스레드 ↔ 메인 스레드 경쟁 상태 방지
    private let peakLock = OSAllocatedUnfairLock<(Float, Float)>(initialState: (0, 0))

    public init() {}

    // MARK: - Attach

    @MainActor
    public func attach(to playerItem: AVPlayerItem) async {
        // macOS 26: MTAudioProcessingTap이 MediaToolbox 내부 스레드(FigAudioQueueSetProperty)에서
        // AVAudioMix 객체의 Swift @MainActor 격리 체크를 트리거 → dispatch_assert_queue_fail 크래시.
        // macOS 26에서는 탭을 비활성화하고 미터를 음소거 상태로 유지.
        if #available(macOS 26, *) { return }

        guard let asset = playerItem.asset as? AVURLAsset,
              let track = (try? await asset.loadTracks(withMediaType: .audio))?.first
        else { return }

        // Retain은 tap 생성 성공 후에 확정 — 생성 실패 시 누수 방지
        let ctxPtr = Unmanaged.passRetained(self).toOpaque()

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: ctxPtr,
            init: { _, clientInfo, storageOut in
                storageOut.pointee = clientInfo
            },
            finalize: { tap in
                let ptr = MTAudioProcessingTapGetStorage(tap)
                Unmanaged<AudioMeterMonitor>.fromOpaque(ptr).release()
            },
            prepare: { _, _, _ in },
            unprepare: { _ in },
            process: { tap, requestedFrames, _, bufferList, framesOut, flagsOut in
                MTAudioProcessingTapGetSourceAudio(tap, requestedFrames, bufferList, flagsOut, nil, framesOut)
                let ptr = MTAudioProcessingTapGetStorage(tap)
                let monitor = Unmanaged<AudioMeterMonitor>.fromOpaque(ptr).takeUnretainedValue()
                monitor.processAudio(bufferList: bufferList, frames: Int(framesOut.pointee))
            }
        )

        var tapRef: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapRef
        )

        guard status == noErr, let tap = tapRef else {
            // 탭 생성 실패 → retain 해제
            Unmanaged<AudioMeterMonitor>.fromOpaque(ctxPtr).release()
            return
        }

        let inputParams = AVMutableAudioMixInputParameters(track: track)
        inputParams.audioTapProcessor = tap

        let mix = AVMutableAudioMix()
        mix.inputParameters = [inputParams]
        playerItem.audioMix = mix
    }

    @MainActor
    public func detach(from playerItem: AVPlayerItem) {
        playerItem.audioMix = nil
        peakLock.withLock { $0 = (0, 0) }
    }

    // MARK: - DSP (audio thread)

    private func processAudio(
        bufferList: UnsafeMutablePointer<AudioBufferList>,
        frames: Int
    ) {
        guard frames > 0 else { return }
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)

        let rmsL: Float
        let rmsR: Float
        if abl.count >= 2 {
            rmsL = computeRMS(abl[0], frames: frames)
            rmsR = computeRMS(abl[1], frames: frames)
        } else if abl.count == 1 {
            rmsL = computeRMS(abl[0], frames: frames)
            rmsR = rmsL
        } else {
            return
        }

        let (peakL, peakR) = peakLock.withLock { state -> (Float, Float) in
            let newL = max(rmsL, state.0 * peakDecay)
            let newR = max(rmsR, state.1 * peakDecay)
            state = (newL, newR)
            return (newL, newR)
        }

        let levels = Levels(left: rmsL, right: rmsR, peakLeft: peakL, peakRight: peakR)
        onLevels?(levels)
    }

    private func computeRMS(_ buffer: AudioBuffer, frames: Int) -> Float {
        guard let data = buffer.mData else { return 0 }
        let byteCount = Int(buffer.mDataByteSize)
        let count = min(frames, byteCount / MemoryLayout<Float>.size)
        guard count > 0 else { return 0 }
        let samples = data.assumingMemoryBound(to: Float.self)
        var rms: Float = 0
        vDSP_measqv(samples, 1, &rms, vDSP_Length(count))
        return sqrt(max(0, rms))
    }
}
