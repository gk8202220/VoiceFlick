import CoreGraphics
import Foundation

enum PowerMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case lowPower
    case paused

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal: "普通模式 15 FPS"
        case .lowPower: "低功耗 10 FPS"
        case .paused: "已暂停"
        }
    }

    var targetFPS: Int32 {
        switch self {
        case .normal: 15
        case .lowPower: 10
        case .paused: 1
        }
    }
}

enum GestureID: Hashable, Codable, Identifiable, Equatable {
    case none
    case closedFist
    case victory
    case pointing
    case thumbsUp
    case wave
    case mouthOpen
    case custom(UUID)

    var id: String {
        switch self {
        case .none: "none"
        case .closedFist: "closedFist"
        case .victory: "victory"
        case .pointing: "pointing"
        case .thumbsUp: "thumbsUp"
        case .wave: "wave"
        case .mouthOpen: "mouthOpen"
        case .custom(let uuid): "custom-\(uuid.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .none: "未识别"
        case .closedFist: "握拳"
        case .victory: "Victory / ✌️"
        case .pointing: "指向"
        case .thumbsUp: "点赞"
        case .wave: "挥手"
        case .mouthOpen: "嘴张开"
        case .custom: "自定义手势"
        }
    }
}

enum BuiltInGestureKind: String, Codable, CaseIterable, Identifiable {
    case closedFist
    case pointing
    case handDown
    case victory
    case thumbsUp
    case wave
    case mouthOpen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .closedFist: "握拳"
        case .pointing: "指向"
        case .handDown: "放下手"
        case .victory: "Victory / ✌️"
        case .thumbsUp: "点赞"
        case .wave: "挥手"
        case .mouthOpen: "嘴张开"
        }
    }

    var gestureID: GestureID? {
        switch self {
        case .closedFist: .closedFist
        case .pointing: .pointing
        case .handDown: nil
        case .victory: .victory
        case .thumbsUp: .thumbsUp
        case .wave: .wave
        case .mouthOpen: .mouthOpen
        }
    }
}

struct BuiltInGestureSettings: Equatable {
    var enabledIDs: Set<String>

    init(enabledIDs: Set<String> = Set(BuiltInGestureKind.allCases.map(\.id))) {
        self.enabledIDs = enabledIDs
    }

    func isEnabled(_ kind: BuiltInGestureKind) -> Bool {
        enabledIDs.contains(kind.id)
    }

    func isEnabled(_ gesture: GestureID) -> Bool {
        switch gesture {
        case .closedFist: isEnabled(BuiltInGestureKind.closedFist)
        case .pointing: isEnabled(BuiltInGestureKind.pointing)
        case .victory: isEnabled(BuiltInGestureKind.victory)
        case .thumbsUp: isEnabled(BuiltInGestureKind.thumbsUp)
        case .wave: isEnabled(BuiltInGestureKind.wave)
        case .mouthOpen: isEnabled(BuiltInGestureKind.mouthOpen)
        case .none, .custom: true
        }
    }

    func isHandDownEnabled() -> Bool {
        isEnabled(BuiltInGestureKind.handDown)
    }
}

struct GestureEvent: Equatable {
    var gesture: GestureID
    var confidence: Double
    var handPresent: Bool
    var timestamp: Date
    var trackingPoint: LandmarkPoint?

    static var empty: GestureEvent {
        GestureEvent(
            gesture: .none,
            confidence: 0,
            handPresent: false,
            timestamp: .now,
            trackingPoint: nil
        )
    }

    var displayTitle: String {
        if !handPresent {
            return "未检测到手"
        }
        return "\(gesture.displayName) · \(Int(confidence * 100))%"
    }
}

struct LandmarkPoint: Codable, Equatable {
    var x: Double
    var y: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct GestureProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var action: ActionMapping
    var threshold: Double
    var templates: [[LandmarkPoint]]

    var isTrained: Bool {
        !templates.isEmpty
    }

    static func empty(index: Int) -> GestureProfile {
        GestureProfile(
            id: UUID(),
            name: "自定义手势 \(index)",
            action: .none,
            threshold: 0.18,
            templates: []
        )
    }
}

struct RuntimeDiagnostics: Equatable {
    var status: String = "尚未启动"
    var processedFrames: Int = 0
    var detectedHands: Int = 0
    var lastError: String = ""
    var lastFrameAt: Date?
    var lastHandAt: Date?

    var summary: String {
        var parts = [
            status,
            "帧 \(processedFrames)",
            "手 \(detectedHands)"
        ]
        if !lastError.isEmpty {
            parts.append("错误: \(lastError)")
        }
        return parts.joined(separator: " · ")
    }
}
