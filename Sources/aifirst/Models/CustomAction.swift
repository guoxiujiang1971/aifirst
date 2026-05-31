import Foundation

struct CustomAction: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var systemPrompt: String
    var userPrompt: String

    init(id: UUID = UUID(), name: String, systemPrompt: String, userPrompt: String = "") {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
    }
}
