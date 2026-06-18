import Foundation

@MainActor
final class GestureProfileStore: ObservableObject {
    @Published var profiles: [GestureProfile] = (1...5).map { GestureProfile.empty(index: $0) } {
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
            let loadedProfiles = try? JSONDecoder().decode([GestureProfile].self, from: data),
            loadedProfiles.count == 5
        else {
            return
        }
        profiles = loadedProfiles
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
