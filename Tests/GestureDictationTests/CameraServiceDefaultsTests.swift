import XCTest
@testable import VoiceFlick

final class CameraServiceDefaultsTests: XCTestCase {
    func testMouthOpenDefaultsWhenUnset() {
        let previousAction = UserDefaults.standard.string(forKey: "mouthOpenAction")
        let previousMouthThreshold = UserDefaults.standard.object(forKey: "mouthOpenConfidenceThreshold")
        let previousAutoStop = UserDefaults.standard.object(forKey: "closeMouthAutoStopEnabled")
        let previousDelay = UserDefaults.standard.object(forKey: "closeMouthAutoStopDelay")
        let previousActionLogging = UserDefaults.standard.object(forKey: "actionLoggingEnabled")
        let previousAudioStop = UserDefaults.standard.object(forKey: "audioSilenceStopEnabled")
        let previousAudioThreshold = UserDefaults.standard.object(forKey: "audioSilenceThresholdDBFS")
        let previousAudioDelay = UserDefaults.standard.object(forKey: "audioSilenceDelay")
        defer {
            if let previousAction {
                UserDefaults.standard.set(previousAction, forKey: "mouthOpenAction")
            } else {
                UserDefaults.standard.removeObject(forKey: "mouthOpenAction")
            }
            if let previousAutoStop {
                UserDefaults.standard.set(previousAutoStop, forKey: "closeMouthAutoStopEnabled")
            } else {
                UserDefaults.standard.removeObject(forKey: "closeMouthAutoStopEnabled")
            }
            if let previousMouthThreshold {
                UserDefaults.standard.set(previousMouthThreshold, forKey: "mouthOpenConfidenceThreshold")
            } else {
                UserDefaults.standard.removeObject(forKey: "mouthOpenConfidenceThreshold")
            }
            if let previousDelay {
                UserDefaults.standard.set(previousDelay, forKey: "closeMouthAutoStopDelay")
            } else {
                UserDefaults.standard.removeObject(forKey: "closeMouthAutoStopDelay")
            }
            if let previousActionLogging {
                UserDefaults.standard.set(previousActionLogging, forKey: "actionLoggingEnabled")
            } else {
                UserDefaults.standard.removeObject(forKey: "actionLoggingEnabled")
            }
            if let previousAudioStop {
                UserDefaults.standard.set(previousAudioStop, forKey: "audioSilenceStopEnabled")
            } else {
                UserDefaults.standard.removeObject(forKey: "audioSilenceStopEnabled")
            }
            if let previousAudioThreshold {
                UserDefaults.standard.set(previousAudioThreshold, forKey: "audioSilenceThresholdDBFS")
            } else {
                UserDefaults.standard.removeObject(forKey: "audioSilenceThresholdDBFS")
            }
            if let previousAudioDelay {
                UserDefaults.standard.set(previousAudioDelay, forKey: "audioSilenceDelay")
            } else {
                UserDefaults.standard.removeObject(forKey: "audioSilenceDelay")
            }
        }

        UserDefaults.standard.removeObject(forKey: "mouthOpenAction")
        UserDefaults.standard.removeObject(forKey: "mouthOpenConfidenceThreshold")
        UserDefaults.standard.removeObject(forKey: "closeMouthAutoStopEnabled")
        UserDefaults.standard.removeObject(forKey: "closeMouthAutoStopDelay")
        UserDefaults.standard.removeObject(forKey: "actionLoggingEnabled")
        UserDefaults.standard.removeObject(forKey: "audioSilenceStopEnabled")
        UserDefaults.standard.removeObject(forKey: "audioSilenceThresholdDBFS")
        UserDefaults.standard.removeObject(forKey: "audioSilenceDelay")

        let service = CameraService()

        XCTAssertEqual(service.mouthOpenAction, .startDictation)
        XCTAssertEqual(service.mouthOpenConfidenceThreshold, 0.80)
        XCTAssertTrue(service.closeMouthAutoStopEnabled)
        XCTAssertEqual(service.closeMouthAutoStopDelay, 3.0)
        XCTAssertTrue(service.actionLoggingEnabled)
        XCTAssertTrue(service.audioSilenceStopEnabled)
        XCTAssertEqual(service.audioSilenceThresholdDBFS, -45.0)
        XCTAssertEqual(service.audioSilenceDelay, 3.0)
    }
}
