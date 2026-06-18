import Foundation

struct ActionLogEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var timestamp: Date
    var gestureName: String
    var actionName: String
    var reason: String
    var confidence: Double
    var audioLevelDBFS: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        gestureName: String,
        actionName: String,
        reason: String,
        confidence: Double,
        audioLevelDBFS: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.gestureName = gestureName
        self.actionName = actionName
        self.reason = reason
        self.confidence = confidence
        self.audioLevelDBFS = audioLevelDBFS
    }

    var confidenceText: String {
        "\(Int(confidence * 100))%"
    }

    var audioText: String? {
        guard let audioLevelDBFS else { return nil }
        return "\(String(format: "%.1f", audioLevelDBFS)) dBFS"
    }

    var timeText: String {
        Self.timeFormatter.string(from: timestamp)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
