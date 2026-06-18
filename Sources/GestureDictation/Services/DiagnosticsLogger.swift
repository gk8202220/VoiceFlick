import Foundation

final class DiagnosticsLogger: @unchecked Sendable {
    static let shared = DiagnosticsLogger()

    let fileURL: URL
    private let queue = DispatchQueue(label: "VoiceFlick.diagnostics")
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VoiceFlick", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        fileURL = baseURL.appendingPathComponent("runtime.log")
        append("logger ready")
    }

    func append(_ message: String) {
        let line = "\(formatter.string(from: .now)) \(message)\n"
        queue.async { [fileURL] in
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let handle = try? FileHandle(forWritingTo: fileURL) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    _ = try? handle.write(contentsOf: data)
                } else {
                    try? data.write(to: fileURL, options: [.atomic])
                }
            }
        }
    }
}
