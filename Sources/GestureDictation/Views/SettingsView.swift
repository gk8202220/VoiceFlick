import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var permissionCoordinator: PermissionCoordinator
    @EnvironmentObject private var cameraService: CameraService
    @AppStorage("showCameraPreview") private var showCameraPreview = false

    var body: some View {
        Form {
            Picker("默认功耗模式", selection: $cameraService.powerMode) {
                ForEach(PowerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Toggle("显示实时视频预览", isOn: $showCameraPreview)

            Toggle("记录动作日志", isOn: $cameraService.actionLoggingEnabled)

            Section("麦克风静音判断") {
                Toggle("启用麦克风静音判断", isOn: $cameraService.audioSilenceStopEnabled)

                VStack(alignment: .leading) {
                    LabeledContent("停止阈值", value: "\(Int(cameraService.audioSilenceThresholdDBFS)) dBFS")
                    Slider(
                        value: $cameraService.audioSilenceThresholdDBFS,
                        in: -60 ... -25,
                        step: 1
                    )
                }
                .disabled(!cameraService.audioSilenceStopEnabled)

                Stepper(
                    "低于阈值保持 \(Int(cameraService.audioSilenceDelay)) 秒后结束",
                    value: $cameraService.audioSilenceDelay,
                    in: 1...10,
                    step: 1
                )
                .disabled(!cameraService.audioSilenceStopEnabled)

                LabeledContent(
                    "当前音量",
                    value: cameraService.audioLevelService.isMonitoring
                        ? "\(String(format: "%.1f", cameraService.audioLevelService.currentLevelDBFS)) dBFS"
                        : "未检测"
                )
            }

            Picker("嘴张开动作", selection: $cameraService.mouthOpenAction) {
                ForEach(ActionMapping.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }

            VStack(alignment: .leading) {
                LabeledContent(
                    "嘴张开启动置信度",
                    value: "\(Int(cameraService.mouthOpenConfidenceThreshold * 100))%"
                )
                Slider(
                    value: $cameraService.mouthOpenConfidenceThreshold,
                    in: 0.45 ... 0.95,
                    step: 0.05
                )
                Text("只有嘴张开识别率达到该值才会执行“嘴张开动作”，默认 80%。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("闭嘴自动结束输入", isOn: $cameraService.closeMouthAutoStopEnabled)

            Stepper(
                "闭嘴保持 \(Int(cameraService.closeMouthAutoStopDelay)) 秒后结束",
                value: $cameraService.closeMouthAutoStopDelay,
                in: 1...10,
                step: 1
            )
            .disabled(!cameraService.closeMouthAutoStopEnabled)

            Section("内置手势启用") {
                ForEach(BuiltInGestureKind.allCases) { kind in
                    Toggle(kind.displayName, isOn: Binding(
                        get: { cameraService.builtInGestureSettings.isEnabled(kind) },
                        set: { cameraService.setBuiltInGesture(kind, enabled: $0) }
                    ))
                }
            }

            LabeledContent("摄像头权限", value: permissionCoordinator.cameraStatusText)
            LabeledContent("麦克风权限", value: permissionCoordinator.microphoneStatusText)
            LabeledContent("辅助功能权限", value: permissionCoordinator.accessibilityStatusText)

            Button("重新检查权限") {
                Task { await permissionCoordinator.refresh() }
            }

            Button("请求麦克风权限") {
                Task { await permissionCoordinator.requestMicrophone() }
            }

            Text("系统语音输入依赖 macOS 设置中的听写快捷键：双击右 Option 开始，单击 Option 结束。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
