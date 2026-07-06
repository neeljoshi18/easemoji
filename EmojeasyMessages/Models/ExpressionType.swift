import Foundation

/// Represents a detected facial expression and its associated emoji candidates.
/// Each expression maps to exactly 3 emoji, ordered by relevance (best match first).
/// The ordering is internal — UI displays all 3 as equally weighted options.
enum ExpressionType: String, CaseIterable, Sendable {
    case smile
    case laugh
    case surprise
    case sadness
    case anger
    case fear
    case disgust
    case kiss
    case wink
    case smirk
    case eyeRoll
    case tongueOut
    case neutral

    /// Exactly 3 emoji candidates, ordered by relevance (position 0 = best match).
    var emojiCandidates: [String] {
        switch self {
        case .smile:     return ["😊", "🙂", "😄"]
        case .laugh:     return ["😂", "😆", "🤣"]
        case .surprise:  return ["😮", "😲", "🤯"]
        case .sadness:   return ["😢", "🙁", "😞"]
        case .anger:     return ["😠", "😤", "😡"]
        case .fear:      return ["😨", "😱", "😰"]
        case .disgust:   return ["🤢", "🤮", "😖"]
        case .kiss:      return ["😘", "😗", "😚"]
        case .wink:      return ["😉", "😜", "😼"]
        case .smirk:     return ["😏", "🤭", "😎"]
        case .eyeRoll:   return ["🙄", "😒", "😮‍💨"]
        case .tongueOut: return ["😛", "😝", "😋"]
        case .neutral:   return ["😐", "😶", "🫥"]
        }
    }

    /// Human-readable name (used in debugging only, not shown to user).
    var displayName: String {
        switch self {
        case .smile:     return "Smile"
        case .laugh:     return "Laugh"
        case .surprise:  return "Surprise"
        case .sadness:   return "Sadness"
        case .anger:     return "Anger"
        case .fear:      return "Fear"
        case .disgust:   return "Disgust"
        case .kiss:      return "Kiss"
        case .wink:      return "Wink"
        case .smirk:     return "Smirk"
        case .eyeRoll:   return "Eye Roll"
        case .tongueOut: return "Tongue Out"
        case .neutral:   return "Neutral"
        }
    }
}
