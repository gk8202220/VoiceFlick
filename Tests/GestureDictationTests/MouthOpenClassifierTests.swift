import CoreGraphics
import XCTest
@testable import VoiceFlick

final class MouthOpenClassifierTests: XCTestCase {
    func testClosedMouthRatioDoesNotPassThreshold() {
        let classifier = MouthOpenClassifier()
        let points = [
            CGPoint(x: 0.10, y: 0.50),
            CGPoint(x: 0.35, y: 0.52),
            CGPoint(x: 0.60, y: 0.50),
            CGPoint(x: 0.35, y: 0.48)
        ]

        let ratio = classifier.mouthOpennessRatio(points)

        XCTAssertNotNil(ratio)
        XCTAssertLessThan(ratio!, classifier.openRatioThreshold)
    }

    func testOpenMouthRatioPassesThreshold() {
        let classifier = MouthOpenClassifier()
        let points = [
            CGPoint(x: 0.10, y: 0.50),
            CGPoint(x: 0.35, y: 0.68),
            CGPoint(x: 0.60, y: 0.50),
            CGPoint(x: 0.35, y: 0.32)
        ]

        let ratio = classifier.mouthOpennessRatio(points)

        XCTAssertNotNil(ratio)
        XCTAssertGreaterThanOrEqual(ratio!, classifier.openRatioThreshold)
    }
}
