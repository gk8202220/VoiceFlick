import Foundation

@MainActor
final class GestureProfileStore: ObservableObject {
    @Published var profiles: [GestureProfile] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VoiceFlick", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        fileURL = baseURL.appendingPathComponent("gesture_profiles.json")
        load()
    }

    func update(_ profile: GestureProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
    }

    func addProfile() {
        profiles.append(GestureProfile.empty(index: nextProfileIndex()))
    }

    func deleteProfile(_ profileID: UUID) {
        profiles.removeAll { $0.id == profileID }
    }

    func appendTemplate(_ template: [LandmarkPoint], to profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].templates.append(template)
    }

    func clearTemplates(for profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].templates.removeAll()
    }

    private func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let loadedProfiles = try? JSONDecoder().decode([GestureProfile].self, from: data)
        else {
            return
        }
        profiles = loadedProfiles.count == 5
            ? loadedProfiles.filter { !isLegacyEmptySlot($0) }
            : loadedProfiles
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func nextProfileIndex() -> Int {
        profiles.count + 1
    }

    private func isLegacyEmptySlot(_ profile: GestureProfile) -> Bool {
        profile.templates.isEmpty
            && profile.action == .none
            && profile.name.hasPrefix("自定义手势 ")
    }
}
