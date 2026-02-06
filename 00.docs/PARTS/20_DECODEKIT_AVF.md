# 20 — DecodeKit (AVFoundation Decoders for MOV/MP4)
- Doc Version: v0.1
- Owner: Engineering (Codex-assisted)
- Definition of Done: All checklist items implemented + tests + docs updated

## Inputs
- Depends on: 10_PLAYERCORE.md
- References: CODEC_POLICY.md, BENCHMARK.md, DECODER_API.md

## Deliverables
- Code: DecoderAVFoundation plugin supporting ProRes/H264/H265 baseline
- Tests/Bench: Seek/step accuracy tests on reference clips
- Docs: DECODER_API.md updated with any differences

## Checklist (Codex)
- [ ] Implement DecoderPlugin for MOV/MP4 using AVFoundation
- [ ] Provide timing mapping (fps, timecode if available)
- [ ] Implement precision decodeFrame(frameIndex) with ±0 accuracy on ProRes
- [ ] Implement prefetch(frames) to warm cache window
- [ ] Gracefully handle unsupported streams (errors surfaced to UI)

## Verification
- Manual smoke test:
- ProRes clip: precision seek/step exact at multiple random frames.
- Automated:
- Benchmark scripted tests pass for ProRes set A (partial in CI, full locally).

## Notes / Decisions
- Separate real-time playback path can still use AVPlayer; DecoderAVF focuses on precision path.
