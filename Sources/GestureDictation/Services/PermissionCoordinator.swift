import AVFoundation
import Foundation

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @Published private(set) var accessibilityTrusted = false

    var cameraGranted: Bool {
        cameraStatus == .authorized
    }

    var microphoneGranted: Bool {
        microphoneStatus == .authorized
    }

    var cameraStatusText: String {
        switch cameraStatus {
        case .authorized: "摄像头已授权"
        case .notDetermined: "摄像头尚未请求"
        case .denied: "摄像头已拒绝"
        case .restricted: "摄像头受限制"
        @unknown default: "摄像头状态未知"
        }
    }

    var accessibilityStatusText: String {
        accessibilityTrusted ? "辅助功能已授权" : "辅助功能未授权"
    }

    var microphoneStatusText: String {
        switch microphoneStatus {
        case .authorized: "麦克风已授权"
        case .notDetermined: "麦克风尚未请求"
        case .denied: "麦克风已拒绝"
        case .restricted: "麦克风受限制"
        @unknown default: "麦克风状态未知"
        }
    }

    func refresh() async {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityTrusted = KeyboardActionService().isAccessibilityTrusted
    }

    func requestCamera() async {
        if cameraStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        await refresh()
    }

    func requestMicrophone() async {
        if microphoneStatus == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        await refresh()
    }

    func requestAccessibility() async {
        KeyboardActionService().requestAccessibilityTrust()
        await refresh()
    }
}
