import AVFoundation
import Foundation

struct AudioLevels: Equatable {
    var rmsDBFS: Double
    var peakDBFS: Double
}

final class AudioLevelService: ObservableObject, @unchecked Sendable {
    @Published private(set) var currentLevelDBFS: Double = -120
    @Published private(set) var peakLevelDBFS: Double = -120
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastError = ""

    private let engine = AVAudioEngine()
    private let minimumDBFS = -120.0

    var isMicrophoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func startMonitoringIfAllowed() {
        guard !isMonitoring else { return }
        guard isMicrophoneAuthorized else {
            lastError = "麦克风未授权"
            return
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let levels = Self.calculateLevels(from: buffer) else { return }
            DispatchQueue.main.async {
                self?.currentLevelDBFS = levels.rmsDBFS
                self?.peakLevelDBFS = levels.peakDBFS
            }
        }

        do {
            engine.prepare()
            try engine.start()
            isMonitoring = true
            lastError = ""
            DiagnosticsLogger.shared.append("audio level monitoring started")
        } catch {
            inputNode.removeTap(onBus: 0)
            isMonitoring = false
            lastError = error.localizedDescription
            DiagnosticsLogger.shared.append("audio level monitoring failed \(error.localizedDescription)")
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isMonitoring = false
        currentLevelDBFS = minimumDBFS
        peakLevelDBFS = minimumDBFS
        DiagnosticsLogger.shared.append("audio level monitoring stopped")
    }

    static func calculateLevels(from buffer: AVAudioPCMBuffer) -> AudioLevels? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return nil }

        var sumSquares: Double = 0
        var peak: Float = 0
        let sampleCount = channelCount * frameLength

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sumSquares += Double(sample * sample)
                peak = max(peak, abs(sample))
            }
        }

        let rms = sqrt(sumSquares / Double(sampleCount))
        return AudioLevels(
            rmsDBFS: dbfs(forAmplitude: rms),
            peakDBFS: dbfs(forAmplitude: Double(peak))
        )
    }

    static func dbfs(forAmplitude amplitude: Double) -> Double {
        guard amplitude > 0 else { return -120 }
        return max(-120, min(0, 20 * log10(amplitude)))
    }
}
