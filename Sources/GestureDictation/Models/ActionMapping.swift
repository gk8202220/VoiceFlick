import Foundation

enum ActionMapping: String, Codable, CaseIterable, Identifiable {
    case startDictation
    case stopDictation
    case pressReturn
    case clearInput
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startDictation: "开始语音输入"
        case .stopDictation: "结束语音输入"
        case .pressReturn: "确认回车"
        case .clearInput: "清除输入框"
        case .none: "无动作"
        }
    }
}
