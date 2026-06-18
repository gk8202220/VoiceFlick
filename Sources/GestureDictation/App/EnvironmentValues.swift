import SwiftUI

private struct KeyboardActionServiceKey: EnvironmentKey {
    static let defaultValue = KeyboardActionService()
}

extension EnvironmentValues {
    var keyboardActionService: KeyboardActionService {
        get { self[KeyboardActionServiceKey.self] }
        set { self[KeyboardActionServiceKey.self] = newValue }
    }
}
