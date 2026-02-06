# RnR — Render / Color Engineer (Metal/LUT/Overlays)
- Scope: Metal rendering pipeline, LUT application, overlay composition

## Responsibilities
- Implement Metal viewer rendering and texture presentation.
- Implement LUT parsing/loading (.cube) + 3D texture representation.
- Apply LUT with intensity; ensure deterministic output (no flicker).
- Compose HUD overlays + burn-in overlays + annotation overlays.
- Provide pixel sampling tool correctness under zoom/pan transforms.

## Primary Deliverables
- `RenderCore` module
- LUT parser tests + render pipeline harness
- Burn-in renderer for export path

## Codex Checklist
- [ ] LUT toggle is stable across frames (no temporal artifacts)
- [ ] Export burn-in matches viewer output
- [ ] Pixel sampler reports consistent values at various zoom levels
