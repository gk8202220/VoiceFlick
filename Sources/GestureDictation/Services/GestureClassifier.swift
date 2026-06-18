import Foundation
import Vision

struct GestureClassifier {
    private let orderedJoints: [VNHumanHandPoseObservation.JointName] = [
        .wrist,
        .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
        .indexMCP, .indexPIP, .indexDIP, .indexTip,
        .middleMCP, .middlePIP, .middleDIP, .middleTip,
        .ringMCP, .ringPIP, .ringDIP, .ringTip,
        .littleMCP, .littlePIP, .littleDIP, .littleTip
    ]

    func classify(
        observation: VNHumanHandPoseObservation,
        profiles: [GestureProfile]
    ) -> (GestureEvent, [LandmarkPoint]?) {
        guard let points = try? observation.recognizedPoints(.all) else {
            return (.empty, nil)
        }

        let normalized = normalizedTemplate(from: points)
        let trackingPoint = reliable(.wrist, in: points).map { LandmarkPoint(x: Double($0.x), y: Double($0.y)) }
        let builtInGesture = classifyBuiltIn(points: points, trackingPoint: trackingPoint)
        let customGesture = normalized.flatMap { classifyCustom(template: $0, profiles: profiles) }

        let selected: GestureEvent
        if let customGesture, customGesture.confidence > max(builtInGesture.confidence, 0.72) {
            var event = customGesture
            event.trackingPoint = trackingPoint
            selected = event
        } else {
            selected = builtInGesture
        }

        return (selected, normalized)
    }

    private func classifyBuiltIn(
        points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
        trackingPoint: LandmarkPoint?
    ) -> GestureEvent {
        guard
            let wrist = reliable(.wrist, in: points),
            let indexTip = reliable(.indexTip, in: points),
            let middleTip = reliable(.middleTip, in: points),
            let ringTip = reliable(.ringTip, in: points),
            let littleTip = reliable(.littleTip, in: points),
            let indexPIP = reliable(.indexPIP, in: points),
            let middlePIP = reliable(.middlePIP, in: points),
            let ringPIP = reliable(.ringPIP, in: points),
            let littlePIP = reliable(.littlePIP, in: points)
        else {
            return event(.none, confidence: 0.2, trackingPoint: trackingPoint)
        }

        let curledFingers = [
            isCurled(tip: indexTip, pip: indexPIP, wrist: wrist),
            isCurled(tip: middleTip, pip: middlePIP, wrist: wrist),
            isCurled(tip: ringTip, pip: ringPIP, wrist: wrist),
            isCurled(tip: littleTip, pip: littlePIP, wrist: wrist)
        ]
        let extendedFingers = [
            isExtended(tip: indexTip, pip: indexPIP, wrist: wrist),
            isExtended(tip: middleTip, pip: middlePIP, wrist: wrist),
            isExtended(tip: ringTip, pip: ringPIP, wrist: wrist),
            isExtended(tip: littleTip, pip: littlePIP, wrist: wrist)
        ]

        if
            let thumbTip = reliable(.thumbTip, in: points),
            let thumbIP = reliable(.thumbIP, in: points),
            isThumbExtendedUp(tip: thumbTip, ip: thumbIP, wrist: wrist),
            curledFingers.allSatisfy({ $0 }),
            thumbTip.y > max(indexTip.y, middleTip.y, ringTip.y, littleTip.y)
        {
            return event(.thumbsUp, confidence: 0.85, trackingPoint: trackingPoint)
        }

        if extendedFingers[0], extendedFingers[1], curledFingers[2], curledFingers[3] {
            return event(.victory, confidence: 0.86, trackingPoint: trackingPoint)
        }

        if extendedFingers[0], curledFingers[1], curledFingers[2], curledFingers[3] {
            return event(.pointing, confidence: 0.83, trackingPoint: trackingPoint)
        }

        if extendedFingers.allSatisfy({ $0 }) {
            return event(.wave, confidence: 0.78, trackingPoint: trackingPoint)
        }

        if curledFingers.allSatisfy({ $0 }) {
            return event(.closedFist, confidence: 0.84, trackingPoint: trackingPoint)
        }

        return event(.none, confidence: 0.35, trackingPoint: trackingPoint)
    }

    private func classifyCustom(template: [LandmarkPoint], profiles: [GestureProfile]) -> GestureEvent? {
        var best: (profile: GestureProfile, distance: Double)?

        for profile in profiles where profile.isTrained {
            for storedTemplate in profile.templates where storedTemplate.count == template.count {
                let distance = averageDistance(template, storedTemplate)
                if best == nil || distance < best!.distance {
                    best = (profile, distance)
                }
            }
        }

        guard let best, best.distance <= best.profile.threshold else {
            return nil
        }

        let confidence = max(0.1, min(0.99, 1.0 - (best.distance / max(best.profile.threshold, 0.01))))
        return GestureEvent(
            gesture: .custom(best.profile.id),
            confidence: confidence,
            handPresent: true,
            timestamp: .now,
            trackingPoint: nil
        )
    }

    private func event(_ gesture: GestureID, confidence: Double, trackingPoint: LandmarkPoint?) -> GestureEvent {
        GestureEvent(
            gesture: gesture,
            confidence: confidence,
            handPresent: true,
            timestamp: .now,
            trackingPoint: trackingPoint
        )
    }

    private func normalizedTemplate(from points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]) -> [LandmarkPoint]? {
        guard
            let wrist = reliable(.wrist, in: points),
            let middleMCP = reliable(.middleMCP, in: points)
        else {
            return nil
        }

        let scale = max(distance(wrist, middleMCP), 0.001)
        var template: [LandmarkPoint] = []

        for joint in orderedJoints {
            guard let point = reliable(joint, in: points) else {
                return nil
            }
            template.append(
                LandmarkPoint(
                    x: Double((point.x - wrist.x) / scale),
                    y: Double((point.y - wrist.y) / scale)
                )
            )
        }

        return template
    }

    private func reliable(
        _ joint: VNHumanHandPoseObservation.JointName,
        in points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint]
    ) -> VNRecognizedPoint? {
        guard let point = points[joint], point.confidence >= 0.28 else {
            return nil
        }
        return point
    }

    private func isCurled(tip: VNRecognizedPoint, pip: VNRecognizedPoint, wrist: VNRecognizedPoint) -> Bool {
        distance(tip, wrist) < distance(pip, wrist) * 1.18 || tip.y < pip.y
    }

    private func isExtended(tip: VNRecognizedPoint, pip: VNRecognizedPoint, wrist: VNRecognizedPoint) -> Bool {
        distance(tip, wrist) > distance(pip, wrist) * 1.25 && tip.y > pip.y
    }

    private func isThumbExtendedUp(tip: VNRecognizedPoint, ip: VNRecognizedPoint, wrist: VNRecognizedPoint) -> Bool {
        distance(tip, wrist) > distance(ip, wrist) * 1.18 && tip.y > ip.y
    }

    private func averageDistance(_ lhs: [LandmarkPoint], _ rhs: [LandmarkPoint]) -> Double {
        zip(lhs, rhs)
            .map { distance($0.cgPoint, $1.cgPoint) }
            .reduce(0, +) / Double(lhs.count)
    }
}
