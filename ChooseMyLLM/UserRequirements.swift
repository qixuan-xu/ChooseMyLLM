import Foundation
import Darwin

// The recommendation engine can consume this value without depending on the UI.
struct UserRequirements {
    var useCase: ModelUseCase = .everyday
    var deployment: ModelDeployment = .either
    var memoryGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    var macChip = MacChip.detected
    var priority: ModelPriority = .balanced
    var needsChinese = false
    var mustBeFree = true
}

enum ModelUseCase: String, CaseIterable, Identifiable, Codable, Sendable {
    case everyday = "Everyday tasks"
    case coding = "Coding"
    case writing = "Writing"
    case studying = "Studying"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .everyday: "bubble.left.and.bubble.right"
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .writing: "pencil.line"
        case .studying: "book"
        }
    }
    var detail: String {
        switch self {
        case .everyday: "Questions, planning, and everyday help."
        case .coding: "Write, explain, and debug code."
        case .writing: "Draft, rewrite, and develop ideas."
        case .studying: "Understand concepts and practice skills."
        }
    }
}

enum ModelDeployment: String, CaseIterable, Identifiable, Codable, Sendable {
    case local = "On my Mac"
    case cloud = "In the cloud"
    case either = "Either works"
    var id: Self { self }
}

enum ModelPriority: String, CaseIterable, Identifiable, Codable, Sendable {
    case speed = "Speed"
    case balanced = "Balanced"
    case quality = "Quality"
    var id: Self { self }
}

enum MacChip: String, CaseIterable, Identifiable, Codable, Sendable {
    case appleSilicon = "Apple silicon (M-series)"
    case intel = "Intel"
    case unknown = "Not sure"
    var id: Self { self }

    static var detected: Self {
        var supported: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("hw.optional.arm64", &supported, &size, nil, 0) == 0 else { return .unknown }
        return supported == 1 ? .appleSilicon : .intel
    }
}
