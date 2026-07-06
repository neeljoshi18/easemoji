# Project Spec: Camera-Based Expression-to-Emoji iMessage Extension

**Status:** Pre-build reference document
**App name:** _[placeholder — not yet decided]_
**Platform:** iOS (iMessage App Extension)
**Doc purpose:** Single source of truth for scope, architecture, and decisions made so far. Any future AI assistant or developer picking this up should be able to build from this without re-deriving the reasoning below.

---

## 1. Core Idea

A user is reading a message, reacts with a facial expression (e.g. smiles because something is funny), and wants to insert the matching emoji without manually searching for it. The app watches the user's face via the front (TrueDepth) camera, detects the expression in real time, and surfaces a ranked set of matching emoji for one-tap insertion into the conversation.

Originally conceived as a custom iOS **keyboard extension** (like Wispr Flow, but for emoji). That approach was investigated and ruled out — see Section 2.

A second mode — pointing the camera at real-world objects to get an object-matching emoji (e.g. point at a dog → 🐕) — is planned as a **future phase**, not part of MVP. See Section 8.

---

## 2. Why This Is NOT a Keyboard Extension (Rejected Architecture)

This was the first architecture considered and explicitly rejected. Documenting the reasoning so it isn't re-litigated:

- iOS **keyboard extensions cannot access the camera** under any configuration, including with "Full Access"/Open Access granted. This is a hard, permanent OS-level restriction — not a permissions toggle.
- Wispr Flow's approach (voice-to-text inside a keyboard) works because **Open Access explicitly permits microphone/audio capture and network access** for keyboard extensions — camera is not in that allowed list, and Apple engineers have confirmed on developer forums that live camera capture inside a keyboard extension is blocked at the API level, full stop.
- The only iOS extension type that **can** access the camera live is an **iMessage App Extension** (confirmed via Apple's own historical demos, e.g. a JibJab-style photo compositor extension).
- Workarounds considered and rejected as inferior UX (kept here for reference in case requirements change):
  - App Group + shared container hand-off between a companion app and keyboard extension (works, but requires app-switching, breaks "seamless" goal).
  - Clipboard hand-off (simpler, but triggers iOS "Pasted from X" system banners and still requires an app switch).
  - URL scheme round-trip between keyboard and companion app (loses keyboard focus, clunky).

**Decision: Build as an iMessage App Extension.** This is the only architecture that supports live, in-context camera access without leaving the Messages conversation.

---

## 3. Platform & Access Model

- **Extension type:** iMessage App Extension (invoked via the App Drawer icon, bottom-left of the Messages keyboard/compose bar).
- **Entry point UX:** User taps the Messages App Drawer icon → selects this app (first use only; iOS pins recently-used iMessage apps near the front of the drawer afterward, making it close to a one-tap reach on repeat use).
- **Important correction to initial assumption:** The App Drawer icon itself cannot be rebranded as "the emoji button" — it's Apple's shared drawer UI for all iMessage apps. The seamless one-tap experience originally envisioned is only achieved after first use, via iOS's own recency-based pinning, not something we control directly.
- **Camera indicator constraint:** iOS shows a system-wide privacy indicator (colored dot at top of screen) whenever the camera is active. This **cannot be suppressed or bypassed** by any entitlement — it is not accessible to third-party apps the way Face ID's Secure Enclave process is. Design decision: **do not render a live camera preview view** (no visible mirror/selfie feed) to minimize self-consciousness, but accept that the system privacy dot will still be visible. This satisfies the "Face ID-like, not self-conscious" goal as closely as iOS permits.
- **Memory/process constraints:** Unlike keyboard extensions (which have historically tight memory ceilings, roughly ~50MB), iMessage extensions run as a near-full app process with substantially more headroom. This means on-device ML models in the tens of MB are not a binding constraint here.

---

## 4. MVP Scope (Phase 1) — Expression Mode Only

Decision: **Ship expression-to-emoji first.** Object-to-emoji mode is explicitly deferred to Phase 2 (Section 8) and should not be built until Phase 1 is working end-to-end.

### 4.1 Functional flow
1. User taps the app in the Messages App Drawer.
2. Camera activates **immediately** on app open — no separate "start capture" tap. No live preview UI is shown to the user (see Section 3 privacy note).
3. On-device face tracking runs for **as long as it takes to get a confident expression read — not rushed, not on a fixed short timer.** Exact duration/confidence threshold to be tuned during implementation, but the guiding principle is: prioritize accurate capture over speed. Once a confident expression is captured, the camera session ends (see point 6).
4. Facial expression is classified from tracked blendshape data (see Section 5).
5. Exactly **3 emoji candidates** are displayed as tappable UI (a row of 3 buttons), with **no visible ranking/confidence indicators** (no size differences, no highlighting, no numbering). All 3 appear as equal-weight options in the UI. However, **the order matters internally**: the first candidate in the row is always the model's best/highest-confidence suggestion, the other two are secondary options — this ordering is positional only, not visually called out. This number (3) is explicitly provisional and may change later.
6. Camera turns off once expression capture is complete (i.e., camera is only active for the capture window, not for the entire time the extension UI is open).
7. User taps one of the 3 emoji candidates → the emoji is **inserted into the Messages compose text field**, appended next to any text already typed there (the same behavior as Apple's own predictive text/QuickType suggestion bar — e.g. typing "ok" and tapping the 👍 suggestion inserts it into the compose field rather than sending it immediately). **No automatic sending** — the user retains full control to edit, add more text, or send manually.
8. **Poor lighting / low-confidence capture:** if lighting conditions are too poor for reliable face tracking, the UI should not attempt to guess — display a clear "Poor lighting" message to the user instead of emoji candidates, and allow retry (e.g. a retry button, or automatically re-attempt once conditions might have changed — exact retry UX still open, see Section 9).

### 4.2 Expression detection approach
- **Do not build a custom-trained facial expression model for this phase.** Apple's **ARKit face tracking** (`ARFaceTrackingConfiguration`, available on any device with a TrueDepth front camera — iPhone X and later) already provides:
  - Real-time 3D face mesh (1,220 points, 60fps)
  - **52 blendshape coefficients** (each 0–1), covering expressions like `mouthSmileLeft`/`mouthSmileRight`, `browInnerUp`, `jawOpen`, `eyeBlinkLeft/Right`, etc.
  - All processing is on-device, using the Neural Engine — no custom model training needed for this mode.
- Build a **thin rules-based (or lightweight classifier) mapping layer** on top of the blendshape coefficients — e.g. `mouthSmileLeft + mouthSmileRight` above a threshold → surface 😄 😁 🙂 as candidates. This mapping layer is the main "logic" to design/tune for Phase 1, not a trained neural net.
- This should be treated as a rules engine first; only consider a trained classifier on top of blendshapes if rules prove insufficient during testing.

---

## 5. Tech Stack (Phase 1)

| Layer | Technology | Notes |
|---|---|---|
| Extension type | iMessage App Extension | `MSMessagesAppViewController` |
| Language | Swift | Standard for iMessage extensions (Storyboard boilerplate still used by Xcode's iMessage extension template as of recent versions — confirm current Xcode template on project start) |
| Camera/Face tracking | ARKit (`ARFaceTrackingConfiguration`) | On-device, no network, no custom model needed |
| UI | **SwiftUI** (decided) | Chosen over UIKit for simpler declarative state-driven UI, well suited to a "camera runs → state changes → 3 emoji buttons appear" flow. Fully supported in iMessage extensions. |
| Expression-to-emoji mapping | Custom Swift logic (rules-based on blendshape coefficients) | Core original logic to build/tune |
| Data/model storage | None required for Phase 1 | ARKit handles all ML on-device; no bundled model needed |
| Minimum iOS/device target | iPhone X or later (TrueDepth camera requirement) | Must state as a hard requirement — no TrueDepth, no face tracking |
| Permissions | `NSCameraUsageDescription` in Info.plist | Required; camera permission prompt on first use |
| Xcode / Swift version | **Latest stable at time of build start** (currently Xcode 16.x / Swift 6, as of this doc's writing) | No legacy-compatibility constraint exists for this project, so pin to whatever is current stable when implementation actually begins rather than hardcoding a version that will go stale |

---

## 6. Explicit Design Decisions Already Made

- ❌ Not a keyboard extension — ruled out for camera restriction reasons (Section 2).
- ✅ iMessage App Extension is the architecture.
- ✅ No live camera preview shown to user (privacy dot still unavoidable, but no mirror image).
- ✅ Use ARKit's built-in face tracking/blendshapes — do not train a custom facial expression model.
- ✅ Phase 1 = expression mode only. Object mode is explicitly out of scope until Phase 1 ships.
- ✅ Object mode (Phase 2, when built) will use a **custom fine-tuned model** on a custom emoji-relevant image dataset — not a pretrained-classifier-plus-lookup-table approach. (Decided by user; dataset sourcing/curation strategy is still undefined — see Open Questions.)
- ✅ No monetization/distribution planning included in this doc by request — purely technical scope.
- ✅ No app name/branding decided yet — treat as placeholder throughout codebase (bundle ID, display name, etc.) until named.
- ✅ Emoji insertion behavior: tapped candidate is inserted into the Messages compose text field next to any existing text (same pattern as Apple's own QuickType/predictive suggestion bar). **Never auto-sent** — user always sends manually.
- ✅ Camera activates immediately on app open (no manual "start capture" step).
- ✅ Camera stays active only for the duration needed to get a confident expression read, then turns off. Explicitly should not be rushed/time-capped artificially — accuracy over speed.
- ✅ Exactly 3 ranked emoji candidates shown per capture (provisional, may change later).
- ✅ Poor lighting handling: show an explicit "Poor lighting" message rather than guessing; no emoji candidates shown in that state.
- ✅ UI framework: SwiftUI (chosen over UIKit for simpler declarative state management, well suited to this flow).
- ✅ Xcode/Swift version: no pinned version — use latest stable available at the time implementation actually begins.

---

## 7. Explicitly Rejected/Deprioritized Ideas (Do Not Re-Propose Without New Information)

- Keyboard extension architecture (Section 2) — technically blocked, not a matter of preference.
- Clipboard-based hand-off between companion app and keyboard — deprioritized in favor of iMessage extension since the latter avoids app-switching entirely.
- Custom-trained model for facial expression detection in Phase 1 — ARKit's built-in blendshapes make this unnecessary; revisit only if rules-based mapping proves inadequate in testing.
- Memoji-specific integration — mentioned early in ideation as a "could extend to" idea but not scoped, decided, or included in Phase 1 or Phase 2. Do not build without explicit future discussion.

---

## 8. Phase 2 (Future, Not Current Scope): Object-to-Emoji Mode

Recorded for context only — do not begin building until Phase 1 (expression mode) is complete and validated.

- **Trigger:** User points the rear (or front) camera at a real-world object; if a matching emoji exists, it's surfaced as a candidate (e.g. ☕ for coffee, 🐕 for a dog).
- **Model approach (decided):** A custom fine-tuned image classification model, trained on a custom emoji-relevant dataset — not a generic pretrained classifier (e.g. MobileNet) with a manual label-to-emoji lookup table. This means dataset curation (what object categories map to which emoji, and sourcing/labeling training images for each) is a prerequisite task before model training can start.
- **Feasibility note carried over from Phase 1 discussion:** iMessage extensions have enough memory headroom (unlike keyboard extensions) to comfortably load an on-device CoreML model in the tens of MB, so on-device inference (rather than server-side) is viable and preferable for latency/privacy.
- **Open item:** Exact emoji category coverage (how many object classes, which emoji set to target first) is undefined and needs scoping when this phase starts.

---

## 9. Open Questions / Unresolved Decisions (Need Answers Before or During Build)

Most implementation-blocking questions have now been resolved (see Section 6). Remaining open items:

1. **Fallback for no TrueDepth camera:** What happens if the app is opened on a device without a TrueDepth front camera (pre-iPhone X)? Needs a defined fallback UX (e.g. disable app, show manual emoji picker, explanatory message).
2. **Poor lighting retry UX:** When "Poor lighting" is shown, should there be an explicit retry button, automatic re-attempt, or does the user just need to reopen the app? Not yet decided.
3. **Confident-capture threshold/timing specifics:** "As long as it takes, not rushed" is the guiding principle, but the actual confidence threshold and any reasonable upper bound (to avoid an indefinite hang if no clear expression is ever detected) still needs to be defined during implementation/testing.
4. **Phase 2 dataset sourcing:** No plan yet for how training images per emoji-object category will be sourced, labeled, or validated for the custom fine-tuned model (Phase 2 only, not blocking Phase 1).

**Instruction for whoever builds from this doc:** Do not assume answers to the above — surface these questions before proceeding on any part of the build that depends on them.

---

## 10. Summary of Immediate Next Steps (Phase 1 Only)

1. Resolve remaining Open Questions in Section 9 where they block the specific piece of work at hand (e.g. confident-capture threshold before tuning the capture logic).
2. Set up Xcode iMessage Extension project target using latest stable Xcode/Swift, with a SwiftUI-based UI.
3. Implement `ARFaceTrackingConfiguration` session: activates immediately on app open, no preview view rendered, runs until a confident expression read or reasonable timeout (threshold TBD), then shuts off.
4. Build blendshape → emoji rules-mapping logic (start with smiling/laughing as the first supported expression given the original use case — reacting to something funny while reading), surfacing exactly 3 ranked candidates.
5. Implement "Poor lighting" fallback state when capture confidence is too low.
6. Build the 3-candidate SwiftUI emoji picker UI, with tap-to-insert into the Messages compose text field (append next to existing text, never auto-send).
7. Test on a physical TrueDepth-capable device (simulator cannot provide real camera/face data).
