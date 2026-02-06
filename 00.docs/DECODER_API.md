# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Decoder Plugin API (DecodeKit)
Goal: support future pro formats (ARRIRAW/HDE, R3D, EXR sequences) without rewriting PlayerCore.

---

## Contracts
- PlayerCore only depends on DecoderPlugin protocol.
- Decoder can output CPU buffers or GPU textures.
- Precision mode requests must return exact frames (±0) for supported formats.

---

## Core Types (Summary)
- DecodeCapability: random access, metadata, timecode, GPU output, etc.
- AssetDescriptor: URL + typeHint
- FrameRequest: frameIndex + priority + allowApproximate
- DecodedFrame: CPU or GPU variant

---

## Protocol (Implementation Target)
- static pluginID / displayName / supportedExtensions
- canOpen(asset) -> Bool
- init(asset) throws
- prepare()
- decodeFrame(request) -> DecodedFrame
- prefetch(frames)
- close()

---

## Format Strategy
- ARRIRAW/HDE: SDK-based decoder plugin producing high-bit-depth frames.
- R3D: SDK decode or proxy-resolver inside plugin.
- EXR sequence: index/parse filenames, prefetch cache window.
