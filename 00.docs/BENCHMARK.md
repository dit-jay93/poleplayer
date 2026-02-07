# PolePlayer (Working Title) — Development Docs
- Date: 2026-02-07 (Asia/Seoul)
- Product: macOS high-end GPU-accelerated video/image player for film/TV/OTT production
- Core pillars: **Frame-accurate playback**, **QC overlays/tools**, **LUT/Look**, **Review/Annotations with persistence**, **Export/Share**


## Benchmark Goals
- Quantify **frame accuracy**, **responsiveness**, **stability** for V1 gates.

---

## Test Clip Set (Reference)
### Set A — ProRes Precision
- 4K UHD or DCI 4K
- fps: 23.976, 24.0, 29.97 (at least one each)
- ProRes 422 HQ (10-bit) + ProRes 4444 (12-bit) at minimum

### Set B — Long-GOP Stress
- H.265 10-bit 4:2:0 (typical) and one “hard” GOP clip
- H.264 baseline clip

### Set C — Edge Conditions (Optional)
- VFR clip (decide support policy)
- Multi-channel audio clip (5.1)

---

## Metrics
### Accuracy
- Frame Step Accuracy: % of steps where displayed frame == expected frame
- Seek Accuracy: seek(frameIndex X) results in frame X (±0 in precision mode)

### Responsiveness
- Step Latency: input -> frame displayed (p50/p95)
- Scrub Latency: scrub -> first valid frame display (p50/p95)

### Stability
- Dropped frames during 10-min playback
- A/V sync drift after 10-min playback (ms)

### Visual Consistency
- LUT toggle does not produce frame-to-frame flicker

---

## Pass Criteria (V1)
### ProRes (Precision Mode)
- Frame Step Accuracy: 100% (±0)
- Seek Accuracy: ±0
- Step Latency p95: < 50 ms (reference machine)
- A/V drift after 10-min: < 20 ms

### H.265/H.264
- Precision seek/step: ±0 on reference clip (latency allowed)
- Real-time playback: “no consistent stutter” on reference machine

---

## Test Procedure (Repeatable)
1) Load clip.
2) Run scripted step test: +1 frame x 1000, record expected vs actual.
3) Random seek test: 100 random seeks; record accuracy and time.
4) LUT toggle test: toggle every 10 frames for 200 frames; check consistency.

---

## Automation CLI
Run locally:
- `swift run PolePlayerBench --input /path/to/clip.mov --output /path/to/output [--lut /path/to/lut.cube]`
- Output: `/path/to/output/benchmark_report.json`

CI / reduced mode:
- `swift run PolePlayerBench --ci --output /tmp/poleplayer_bench`
- Generates a tiny H.264 clip and runs a reduced iteration set.
