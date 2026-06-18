import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var permissionCoordinator: PermissionCoordinator
    @EnvironmentObject private var profileStore: GestureProfileStore
    @EnvironmentObject private var cameraService: CameraService
    @Environment(\.keyboardActionService) private var keyboardActionService
    @AppStorage("showCameraPreview") private var showCameraPreview = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .task {
            await permissionCoordinator.refresh()
        }
    }

    private var sidebar: some View {
        List {
            Section("状态") {
                StatusRow(title: "摄像头", value: permissionCoordinator.cameraStatusText, symbol: "camera")
                StatusRow(title: "麦克风", value: permissionCoordinator.microphoneStatusText, symbol: "mic")
                StatusRow(title: "辅助功能", value: permissionCoordinator.accessibilityStatusText, symbol: "keyboard")
                StatusRow(title: "识别", value: cameraService.currentEvent.displayTitle, symbol: "hand.raised")
                StatusRow(title: "功耗", value: cameraService.powerMode.displayName, symbol: "battery.75")
                StatusRow(title: "诊断", value: cameraService.diagnostics.summary, symbol: "waveform.path.ecg")
            }

            Section("控制") {
                Button(cameraService.isRunning ? "暂停摄像头" : "启动摄像头") {
                    cameraService.toggleRunning()
                }
                Picker("功耗模式", selection: $cameraService.powerMode) {
                    ForEach(PowerMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("训练槽位") {
                ForEach(profileStore.profiles) { profile in
                    HStack {
                        Image(systemName: profile.isTrained ? "checkmark.seal.fill" : "circle.dashed")
                            .foregroundStyle(profile.isTrained ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(profile.name)
                            Text("\(profile.templates.count) 个样本 · \(profile.action.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("VoiceFlick")
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cameraCard
                audioLevelCard
                builtInGesturesCard
                actionLogCard
                permissionsCard
                TrainingView()
                    .environmentObject(profileStore)
                    .environmentObject(cameraService)
            }
            .padding(24)
        }
        .background(.regularMaterial)
    }

    private var cameraCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("实时手势识别")
                        .font(.title2.bold())
                    Text("握拳或指向开始输入，放下结束，Victory 或点赞确认，挥手清空。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(cameraService.currentEvent.displayTitle)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                Toggle("显示视频", isOn: $showCameraPreview)
                    .toggleStyle(.switch)
            }

            if showCameraPreview {
                CameraPreviewView(session: cameraService.session)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .frame(height: 380)
                    .overlay(alignment: .bottomLeading) {
                        Text(cameraService.isRunning ? "Camera Active" : "Camera Paused")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.5), in: Capsule())
                            .foregroundStyle(.white)
                            .padding()
                    }
            } else {
                previewHiddenPlaceholder
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var audioLevelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("麦克风静音判断")
                        .font(.title3.bold())
                    Text("只在语音输入开启后检测 dBFS；低于阈值且没有张嘴持续达标才自动结束。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("启用", isOn: $cameraService.audioSilenceStopEnabled)
                    .toggleStyle(.switch)
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(audioLevelText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(audioLevelSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 150, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: audioProgress)
                        .tint(audioIsBelowThreshold ? .orange : .green)
                    HStack {
                        Text("阈值 \(String(format: "%.0f", cameraService.audioSilenceThresholdDBFS)) dBFS")
                        Spacer()
                        Text("低音量 \(Int(cameraService.audioSilenceDelay)) 秒后可停止")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var actionLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("动作日志")
                        .font(.title3.bold())
                    Text("记录什么时候识别到什么姿势，并执行了什么动作。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("记录日志", isOn: $cameraService.actionLoggingEnabled)
                    .toggleStyle(.switch)
                Button("清空") {
                    cameraService.clearActionLog()
                }
                .buttonStyle(.bordered)
                .disabled(cameraService.actionLogEntries.isEmpty)
            }

            if cameraService.actionLogEntries.isEmpty {
                ContentUnavailableView(
                    cameraService.actionLoggingEnabled ? "还没有动作日志" : "动作日志已关闭",
                    systemImage: cameraService.actionLoggingEnabled ? "list.bullet.rectangle" : "list.bullet.rectangle.portrait",
                    description: Text(cameraService.actionLoggingEnabled ? "触发手势动作后会显示在这里。" : "打开“记录日志”后，只记录新的动作。")
                )
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(cameraService.actionLogEntries.prefix(12)) { entry in
                        ActionLogRow(entry: entry)
                    }
                }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var previewHiddenPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("实时视频已隐藏")
                .font(.headline)
            Text("识别仍在运行；隐藏预览可减少界面渲染和 GPU 合成开销。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Label(cameraService.isRunning ? "摄像头运行中" : "摄像头已暂停", systemImage: cameraService.isRunning ? "camera.fill" : "pause.circle.fill")
                Label(cameraService.currentEvent.displayTitle, systemImage: "hand.raised.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var builtInGesturesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("内置手势")
                        .font(.title3.bold())
                    Text("这些手势无需训练，识别稳定后会直接触发对应功能。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(BuiltInGestureInfo.all.count) 个", systemImage: "hand.raised.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(BuiltInGestureInfo.all) { gesture in
                    BuiltInGestureRow(
                        info: gesture,
                        isEnabled: cameraService.builtInGestureSettings.isEnabled(gesture.kind)
                    ) { enabled in
                        cameraService.setBuiltInGesture(gesture.kind, enabled: enabled)
                    }
                }
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                PermissionButton(
                    title: permissionCoordinator.cameraStatusText,
                    symbol: "camera.fill",
                    isGranted: permissionCoordinator.cameraGranted
                ) {
                    Task { await permissionCoordinator.requestCamera() }
                }
                PermissionButton(
                    title: permissionCoordinator.microphoneStatusText,
                    symbol: "mic.fill",
                    isGranted: permissionCoordinator.microphoneGranted
                ) {
                    Task { await permissionCoordinator.requestMicrophone() }
                }
                PermissionButton(
                    title: permissionCoordinator.accessibilityStatusText,
                    symbol: "figure.wave",
                    isGranted: permissionCoordinator.accessibilityTrusted
                ) {
                    Task { await permissionCoordinator.requestAccessibility() }
                }
                Button("测试 Return") {
                    keyboardActionService.perform(.pressReturn)
                }
                .buttonStyle(.bordered)
                Button("测试开始输入") {
                    keyboardActionService.perform(.startDictation)
                }
                .buttonStyle(.bordered)
                Button("重置识别状态") {
                    cameraService.resetRecognitionState()
                }
                .buttonStyle(.bordered)
            }

            Text(cameraService.diagnostics.summary)
                .font(.callout.monospacedDigit())
                .foregroundStyle(cameraService.diagnostics.lastError.isEmpty ? Color.secondary : Color.orange)
            if !permissionCoordinator.microphoneGranted, cameraService.audioSilenceStopEnabled {
                Text("麦克风未授权时，静音判断不可用；嘴张开输入会回退到闭嘴保持时间结束。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("运行日志: \(DiagnosticsLogger.shared.fileURL.path)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var audioLevelText: String {
        guard cameraService.audioLevelService.isMonitoring else { return "未检测" }
        return "\(String(format: "%.1f", cameraService.audioLevelService.currentLevelDBFS)) dBFS"
    }

    private var audioLevelSubtitle: String {
        if !permissionCoordinator.microphoneGranted {
            return "麦克风未授权"
        }
        if !cameraService.audioSilenceStopEnabled {
            return "静音判断已关闭"
        }
        return cameraService.audioLevelService.isMonitoring ? (audioIsBelowThreshold ? "低于停止阈值" : "正在说话/有声音") : "等待语音输入开始"
    }

    private var audioIsBelowThreshold: Bool {
        cameraService.audioLevelService.currentLevelDBFS < cameraService.audioSilenceThresholdDBFS
    }

    private var audioProgress: Double {
        guard cameraService.audioLevelService.isMonitoring else { return 0 }
        return min(max((cameraService.audioLevelService.currentLevelDBFS + 60) / 60, 0), 1)
    }
}

private struct BuiltInGestureInfo: Identifiable {
    let kind: BuiltInGestureKind
    let title: String
    let gestureDescription: String
    let action: String
    let symbol: String
    let tint: Color

    var id: String { kind.id }

    static let all: [BuiltInGestureInfo] = [
        BuiltInGestureInfo(
            kind: .closedFist,
            title: "握拳",
            gestureDescription: "四指弯曲，稳定出现约 300ms",
            action: "开始语音输入",
            symbol: "hand.fist.fill",
            tint: .blue
        ),
        BuiltInGestureInfo(
            kind: .pointing,
            title: "指向",
            gestureDescription: "食指伸直，其他三指弯曲",
            action: "开始语音输入",
            symbol: "hand.point.up.left.fill",
            tint: .blue
        ),
        BuiltInGestureInfo(
            kind: .handDown,
            title: "放下手",
            gestureDescription: "手消失或不再保持开始手势约 500ms",
            action: "结束语音输入",
            symbol: "hand.raised.slash.fill",
            tint: .orange
        ),
        BuiltInGestureInfo(
            kind: .victory,
            title: "Victory / ✌️",
            gestureDescription: "食指和中指伸直，无名指和小指弯曲",
            action: "确认回车",
            symbol: "hand.peace.fill",
            tint: .green
        ),
        BuiltInGestureInfo(
            kind: .thumbsUp,
            title: "点赞",
            gestureDescription: "拇指向上，其他四指弯曲",
            action: "确认回车",
            symbol: "hand.thumbsup.fill",
            tint: .green
        ),
        BuiltInGestureInfo(
            kind: .wave,
            title: "挥手",
            gestureDescription: "张开手掌并横向摆动",
            action: "清除输入框",
            symbol: "hands.sparkles.fill",
            tint: .red
        ),
        BuiltInGestureInfo(
            kind: .mouthOpen,
            title: "嘴张开",
            gestureDescription: "正脸张嘴稳定约 300ms",
            action: "开始语音输入",
            symbol: "face.smiling.fill",
            tint: .purple
        )
    ]
}

private struct BuiltInGestureRow: View {
    let info: BuiltInGestureInfo
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: info.symbol)
                .font(.title3)
                .foregroundStyle(isEnabled ? info.tint : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(info.title)
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: onToggle
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                Text(info.gestureDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isEnabled ? info.action : "已关闭")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isEnabled ? info.tint : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isEnabled ? info.tint : Color.secondary).opacity(0.12), in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isEnabled ? .thinMaterial : .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(isEnabled ? 1.0 : 0.62)
    }
}

private struct StatusRow: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(title)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }
}

private struct ActionLogRow: View {
    let entry: ActionLogEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.timeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.gestureName)
                    .font(.headline)
                Text(actionLogDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.actionName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(.blue)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionLogDetailText: String {
        var parts = ["原因: \(entry.reason)", "置信度 \(entry.confidenceText)"]
        if let audioText = entry.audioText {
            parts.append("音量 \(audioText)")
        }
        return parts.joined(separator: " · ")
    }
}

private struct PermissionButton: View {
    var title: String
    var symbol: String
    var isGranted: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isGranted ? "checkmark.circle.fill" : symbol)
        }
        .buttonStyle(.borderedProminent)
        .tint(isGranted ? .green : .orange)
    }
}
