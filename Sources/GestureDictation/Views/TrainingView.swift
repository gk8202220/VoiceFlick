import SwiftUI

struct TrainingView: View {
    @EnvironmentObject private var profileStore: GestureProfileStore
    @EnvironmentObject private var cameraService: CameraService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("5 组自定义手势")
                    .font(.title2.bold())
                Text("摆好手势后点击采集样本。每组建议采集 8-12 次，略微改变角度。")
                    .foregroundStyle(.secondary)
            }

            ForEach($profileStore.profiles) { $profile in
                ProfileEditorRow(profile: $profile)
                    .environmentObject(profileStore)
                    .environmentObject(cameraService)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ProfileEditorRow: View {
    @Binding var profile: GestureProfile
    @EnvironmentObject private var profileStore: GestureProfileStore
    @EnvironmentObject private var cameraService: CameraService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("手势名称", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
                Picker("动作", selection: $profile.action) {
                    ForEach(ActionMapping.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .frame(width: 180)
            }

            HStack {
                Text("样本 \(profile.templates.count)")
                    .foregroundStyle(.secondary)
                Slider(value: $profile.threshold, in: 0.08...0.35) {
                    Text("阈值")
                }
                Text(String(format: "%.2f", profile.threshold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("采集当前手势") {
                    cameraService.captureTrainingSample(for: profile.id)
                }
                .disabled(cameraService.latestTemplate == nil)
                Button("清空") {
                    profileStore.clearTemplates(for: profile.id)
                }
                .disabled(profile.templates.isEmpty)
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: profile) { _, newValue in
            profileStore.update(newValue)
        }
    }
}
