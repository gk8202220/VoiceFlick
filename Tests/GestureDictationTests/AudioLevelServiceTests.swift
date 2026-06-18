import AVFoundation
import XCTest
@testable import VoiceFlick

final class AudioLevelServiceTests: XCTestCase {
    func testDBFSForAmplitude() {
        XCTAssertEqual(AudioLevelService.dbfs(forAmplitude: 1.0), 0, accuracy: 0.001)
        XCTAssertEqual(AudioLevelService.dbfs(forAmplitude: 0.5), -6.0206, accuracy: 0.001)
        XCTAssertEqual(AudioLevelService.dbfs(forAmplitude: 0), -120, accuracy: 0.001)
    }

    func testCalculateLevelsFromSilentBuffer() throws {
        let buffer = try makeBuffer(samples: [0, 0, 0, 0])

        let levels = try XCTUnwrap(AudioLevelService.calculateLevels(from: buffer))

        XCTAssertEqual(levels.rmsDBFS, -120, accuracy: 0.001)
        XCTAssertEqual(levels.peakDBFS, -120, accuracy: 0.001)
    }

    func testCalculateLevelsFromFixedAmplitudeBuffer() throws {
        let buffer = try makeBuffer(samples: [0.5, -0.5, 0.5, -0.5])

        let levels = try XCTUnwrap(AudioLevelService.calculateLevels(from: buffer))

        XCTAssertEqual(levels.rmsDBFS, -6.0206, accuracy: 0.001)
        XCTAssertEqual(levels.peakDBFS, -6.0206, accuracy: 0.001)
    }

    private func makeBuffer(samples: [Float]) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }
        return buffer
    }
}
