# DEV_LOG

## 2026-02-07 01:51 KST
- Initialized tracking artifacts: STATUS, PROGRESS_CHECKLIST, DEV_LOG, TEST_NOTES.
- No code changes yet.

## 2026-02-07 02:14 KST
- Decision: Use Swift Package scaffold with modular targets (open `Package.swift` in Xcode) instead of generating a separate `.xcworkspace` for now. Rationale: no generator installed; SPM keeps modules clean while M0 is prioritized.
- Decision: M0 playback uses AVPlayer for real-time and precision (seek with zero tolerance); DecodeKit precision path is a follow-up. Rationale: deliver earliest testable playback.
- Note: Reverse playback via manual frame-step timer when J is pressed (fallback for negative rate support).
- Verification: `swift build` and `swift test` passed locally.
