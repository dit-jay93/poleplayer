# RnR — Decode / Media Engineer
- Scope: DecodeKit, AVFoundation decoder plugin, format policy enforcement

## Responsibilities
- Implement DecoderPlugin(s) for MOV/MP4 using AVFoundation baseline.
- Provide frame-accurate decode in Precision mode for supported formats.
- Implement prefetch/caching hints to stabilize step/seek.
- Enforce format policy (supported/partial/unsupported) and surface errors.
- Prepare extension path for pro formats via plugins (ARRI/RED/EXR).

## Primary Deliverables
- `DecodeKit` + `DecoderAVFoundation`
- Seek/step accuracy tests for reference clips
- Error handling contract to UI layer

## Codex Checklist
- [ ] ProRes: precision seek/step exact on random frames
- [ ] H.265/H.264: precision seek exact on reference clips
- [ ] Unsupported formats produce deterministic error codes/messages
