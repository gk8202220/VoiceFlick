import CoreGraphics
import Vision

func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
    let dx = lhs.x - rhs.x
    let dy = lhs.y - rhs.y
    return Double((dx * dx + dy * dy).squareRoot())
}

func distance(_ lhs: VNRecognizedPoint, _ rhs: VNRecognizedPoint) -> Double {
    distance(lhs.location, rhs.location)
}
