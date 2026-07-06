import ARKit

/// Rules-based classifier that maps ARKit blendshape coefficients to an ExpressionType.
///
/// Evaluates expressions in priority order (most specific first) and returns the
/// first match. This prevents ambiguity — e.g., laugh includes smile signals,
/// so laugh is checked before smile.
///
/// Priority order:
/// 1. Laugh (superset of smile)
/// 2. Wink (asymmetric eye blink)
/// 3. Kiss (mouth pucker)
/// 4. Tongue Out
/// 5. Surprise (wide eyes + open mouth + raised brows)
/// 6. Anger (furrowed brows + frown)
/// 7. Sadness (frown without anger signals)
/// 8. Smile (simplest — just mouth corners up)
/// 9. Neutral (fallback)
@MainActor
final class ExpressionClassifier: Sendable {

    // MARK: - Tunable Thresholds

    /// Minimum average smile (mouthSmileLeft + mouthSmileRight) / 2 for a smile.
    private let smileThreshold: Float = 0.4

    /// Minimum average smile for laugh (higher than plain smile).
    private let laughSmileThreshold: Float = 0.5

    /// Minimum jawOpen for laugh.
    private let laughJawOpenThreshold: Float = 0.3

    /// Minimum jawOpen for surprise.
    private let surpriseJawOpenThreshold: Float = 0.4

    /// Minimum average eyeWide for surprise.
    private let surpriseEyeWideThreshold: Float = 0.3

    /// Minimum browInnerUp for surprise.
    private let surpriseBrowThreshold: Float = 0.4

    /// Minimum average mouthFrown for sadness.
    private let sadnessFrownThreshold: Float = 0.3

    /// Maximum average smile allowed for sadness (to distinguish from smile).
    private let sadnessMaxSmile: Float = 0.2

    /// Minimum average browDown for anger.
    private let angerBrowDownThreshold: Float = 0.4

    /// Minimum average mouthFrown for anger.
    private let angerFrownThreshold: Float = 0.3

    /// Maximum jawOpen for anger (jaw should be relatively closed).
    private let angerMaxJawOpen: Float = 0.15

    /// Minimum mouthPucker for kiss.
    private let kissPuckerThreshold: Float = 0.5

    /// Minimum eye blink value for the closed eye in a wink.
    private let winkClosedEyeThreshold: Float = 0.7

    /// Maximum eye blink value for the open eye in a wink.
    private let winkOpenEyeThreshold: Float = 0.3

    /// Minimum tongueOut for tongue out expression.
    private let tongueOutThreshold: Float = 0.4

    // MARK: - Classification

    /// Classifies blendshape data into an expression type.
    /// - Parameter blendShapes: Dictionary of blendshape locations to their coefficient values (0.0–1.0).
    /// - Returns: The detected `ExpressionType`, or `.neutral` if no expression matches.
    func classify(blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> ExpressionType {
        // Extract commonly used values
        let smileLeft = value(blendShapes, .mouthSmileLeft)
        let smileRight = value(blendShapes, .mouthSmileRight)
        let avgSmile = (smileLeft + smileRight) / 2.0

        let jawOpen = value(blendShapes, .jawOpen)

        let eyeWideLeft = value(blendShapes, .eyeWideLeft)
        let eyeWideRight = value(blendShapes, .eyeWideRight)
        let avgEyeWide = (eyeWideLeft + eyeWideRight) / 2.0

        let browInnerUp = value(blendShapes, .browInnerUp)
        let browDownLeft = value(blendShapes, .browDownLeft)
        let browDownRight = value(blendShapes, .browDownRight)
        let avgBrowDown = (browDownLeft + browDownRight) / 2.0

        let frownLeft = value(blendShapes, .mouthFrownLeft)
        let frownRight = value(blendShapes, .mouthFrownRight)
        let avgFrown = (frownLeft + frownRight) / 2.0

        let mouthPucker = value(blendShapes, .mouthPucker)

        let eyeBlinkLeft = value(blendShapes, .eyeBlinkLeft)
        let eyeBlinkRight = value(blendShapes, .eyeBlinkRight)

        let tongueOut = value(blendShapes, .tongueOut)

        let eyeLookUpLeft = value(blendShapes, .eyeLookUpLeft)
        let eyeLookUpRight = value(blendShapes, .eyeLookUpRight)
        let avgEyeLookUp = (eyeLookUpLeft + eyeLookUpRight) / 2.0

        let noseSneerLeft = value(blendShapes, .noseSneerLeft)
        let noseSneerRight = value(blendShapes, .noseSneerRight)
        
        let mouthStretchLeft = value(blendShapes, .mouthStretchLeft)
        let mouthStretchRight = value(blendShapes, .mouthStretchRight)
        let avgMouthStretch = (mouthStretchLeft + mouthStretchRight) / 2.0

        let mouthShrugLower = value(blendShapes, .mouthShrugLower)

        // 1. Laugh — smile + open mouth (check before smile since it's a superset)
        if avgSmile >= laughSmileThreshold && jawOpen >= laughJawOpenThreshold {
            return .laugh
        }

        // 2. Wink — Based on data, users squint both eyes, but one much more.
        let blinkDiff = abs(eyeBlinkLeft - eyeBlinkRight)
        let maxBlink = max(eyeBlinkLeft, eyeBlinkRight)
        if maxBlink > 0.6 && blinkDiff > 0.25 {
            return .wink
        }

        // 3. Kiss — mouth pucker is very strong (0.9+)
        if mouthPucker >= 0.5 { // Safe threshold
            return .kiss
        }

        // 4. Tongue Out
        if tongueOut >= tongueOutThreshold {
            return .tongueOut
        }

        // 5. Disgust — nose sneer and brow down/mouth shrug
        if max(noseSneerLeft, noseSneerRight) >= 0.4 || (max(noseSneerLeft, noseSneerRight) >= 0.25 && mouthShrugLower >= 0.25 && avgBrowDown >= 0.3) {
            return .disgust
        }

        // 6. Eye Roll — eyes looking up significantly
        if avgEyeLookUp >= 0.6 {
            return .eyeRoll
        }

        // 7. Fear — wide eyes + slight brow up + mouth stretch
        if avgEyeWide >= 0.35 && browInnerUp >= 0.15 && avgMouthStretch >= 0.15 {
            return .fear
        }

        // 8. Surprise — wide eyes + open mouth + raised brows
        if jawOpen >= surpriseJawOpenThreshold
            && avgEyeWide >= surpriseEyeWideThreshold
            && browInnerUp >= surpriseBrowThreshold {
            return .surprise
        }

        // 9. Anger — furrowed brows + frown + jaw relatively closed
        if avgBrowDown >= angerBrowDownThreshold
            && avgFrown >= angerFrownThreshold
            && jawOpen < angerMaxJawOpen {
            return .anger
        }

        // 10. Sadness — frown without anger-level brow furrow, and not smiling
        if avgFrown >= sadnessFrownThreshold && avgSmile < sadnessMaxSmile {
            return .sadness
        }

        // 11. Smirk — Users often smile with both sides, but shrug the lower lip and sneer slightly
        let smileDifference = abs(smileLeft - smileRight)
        if (avgSmile >= 0.3 && smileDifference >= 0.15) || (avgSmile >= 0.3 && mouthShrugLower >= 0.25) {
            return .smirk
        }

        // 12. Smile — simplest expression, just mouth corners up
        if avgSmile >= smileThreshold {
            return .smile
        }

        // 13. Neutral — no expression matched
        return .neutral
    }

    // MARK: - Helpers

    /// Safely extracts a Float value from the blendshape dictionary.
    private func value(
        _ shapes: [ARFaceAnchor.BlendShapeLocation: NSNumber],
        _ key: ARFaceAnchor.BlendShapeLocation
    ) -> Float {
        shapes[key]?.floatValue ?? 0.0
    }
}
