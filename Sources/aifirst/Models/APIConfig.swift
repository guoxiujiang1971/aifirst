import Foundation

struct APIConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var baseURL: String
    var model: String
    var apiKey: String = ""
    var temperature: Double = 0.7
    var maxTokens: Int = 2048
    var isEnabled: Bool = false
}
