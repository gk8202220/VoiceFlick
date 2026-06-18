import CoreGraphics
import Foundation
import Vision

struct MouthOpenClassifier {
    let openRatioThreshold: Double = 0.28

    func classify(observation: VNFaceObservation) -> GestureEvent? {
        guard
            let landmarks = observation.landmarks,
            let mouthRegion = landmarks.innerLips ?? landmarks.outerLips,
            let points = mouthPoints(from: mouthRegion),
            let openness = mouthOpennessRatio(points),
            openness >= openRatioThreshold
        else {
            return nil
        }

        let confidence = min(0.95, max(0.45, openness / max(openRatioThreshold * 2.0, 0.01)))
        return GestureEvent(
            gesture: .mouthOpen,
            confidence: confidence,
            handPresent: true,
            timestamp: .now,
            trackingPoint: nil
        )
    }

    func mouthOpennessRatio(_ points: [CGPoint]) -> Double? {
        guard points.count >= 4 else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        guard
            let minX = xs.min(),
            let maxX = xs.max(),
            let minY = ys.min(),
            let maxY = ys.max()
        else {
            return nil
        }

        let width = max(Double(maxX - minX), 0.001)
        let height = Double(maxY - minY)
        return height / width
    }

    private func mouthPoints(from region: VNFaceLandmarkRegion2D) -> [CGPoint]? {
        guard region.pointCount >= 4 else {
            return nil
        }

        let normalizedPoints = region.normalizedPoints
        return (0..<region.pointCount).map { normalizedPoints[$0] }
    }
}
