import Foundation

struct APIMessage: Codable {
    let role: String
    let content: String
}

struct APIRequestBody: Codable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let temperature: Double
    let max_tokens: Int
}

struct APIStreamChunk: Codable {
    let choices: [APIStreamChoice]?
}

struct APIStreamChoice: Codable {
    let delta: APIStreamDelta
}

struct APIStreamDelta: Codable {
    let content: String?
}

struct APIResponse: Codable {
    let choices: [APIResponseChoice]?
}

struct APIResponseChoice: Codable {
    let message: APIResponseMessage
}

struct APIResponseMessage: Codable {
    let content: String
}

enum AIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return LocalizationService.shared.tr("api_missing_key")
        case .invalidURL: return LocalizationService.shared.tr("api_invalid_url")
        case .serverError(let code): return "\(LocalizationService.shared.tr("api_server_error")) (HTTP \(code))"
        }
    }
}

class AIService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    @MainActor
    func send(_ text: String) async {
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isLoading = true

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)

        do {
            try await streamResponse { chunk in
                await MainActor.run {
                    if !self.messages.isEmpty {
                        self.messages[self.messages.count - 1].content += chunk
                    }
                }
            }
        } catch let error as AIError {
            if !self.messages.isEmpty {
                self.messages[self.messages.count - 1].content = error.localizedDescription
            }
        } catch {
            if !self.messages.isEmpty {
                self.messages[self.messages.count - 1].content = "\(LocalizationService.shared.tr("error_unknown")): \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    func testConnection() async -> String {
        await performTest(
            baseURL: settings.baseURL,
            apiKey: settings.apiKey,
            model: settings.model,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens
        )
    }

    func testConnection(for config: APIConfig) async -> String {
        await performTest(
            baseURL: config.baseURL,
            apiKey: config.apiKey,
            model: config.model,
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
    }

    private func performTest(baseURL: String, apiKey: String, model: String, temperature: Double, maxTokens: Int) async -> String {
        guard let url = URL(string: buildBaseURL(from: baseURL)) else { return LocalizationService.shared.tr("api_invalid_url") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let testMessages = [APIMessage(role: "user", content: "Hello")]
        let body = APIRequestBody(
            model: model,
            messages: testMessages,
            stream: false,
            temperature: temperature,
            max_tokens: 1
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return "无效的服务器响应"
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorText = String(data: data, encoding: .utf8) {
                    return "HTTP \(httpResponse.statusCode): \(errorText.prefix(200))"
                }
                return "HTTP \(httpResponse.statusCode)"
            }

            let result = try JSONDecoder().decode(APIResponse.self, from: data)
            guard let content = result.choices?.first?.message.content else {
                return LocalizationService.shared.tr("api_response_error")
            }
            return "✅ \(LocalizationService.shared.tr("api_test_success")): \(content.prefix(100))"
        } catch {
            return "❌ 连接失败: \(error.localizedDescription)"
        }
    }

    private func buildBaseURL() -> String {
        buildBaseURL(from: settings.baseURL)
    }

    private func buildBaseURL(from baseURL: String) -> String {
        var base = baseURL.trimmingCharacters(in: .whitespaces)
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        if !base.hasSuffix("/chat/completions") {
            if base.hasSuffix("/v1") || base.hasSuffix("/v1/") {
                base += "/chat/completions"
            } else {
                base += "/v1/chat/completions"
            }
        }
        return base
    }

    private func streamResponse(onChunk: @escaping (String) async -> Void) async throws {
        guard let url = URL(string: buildBaseURL()) else { throw AIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let apiMessages: [APIMessage] = messages.map {
            APIMessage(role: $0.role.rawValue, content: $0.content)
        }

        let body = APIRequestBody(
            model: settings.model,
            messages: apiMessages,
            stream: true,
            temperature: settings.temperature,
            max_tokens: settings.maxTokens
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.serverError(-1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIError.serverError(httpResponse.statusCode)
        }

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }

            let jsonStr = line.dropFirst(6)
            guard jsonStr != "[DONE]" else { break }

            guard let data = jsonStr.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(APIStreamChunk.self, from: data),
                  let content = chunk.choices?.first?.delta.content
            else { continue }

            await onChunk(content)
        }
    }

    func quickAction(systemPrompt: String, userPrompt: String = "", text: String) async throws -> String {
        guard let url = URL(string: buildBaseURL()) else { throw AIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let userContent = userPrompt.isEmpty ? text : userPrompt + "\n\n" + text
        let messages = [
            APIMessage(role: "system", content: systemPrompt),
            APIMessage(role: "user", content: userContent)
        ]
        let body = APIRequestBody(
            model: settings.model,
            messages: messages,
            stream: false,
            temperature: settings.temperature,
            max_tokens: settings.maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let result = try JSONDecoder().decode(APIResponse.self, from: data)
        guard let content = result.choices?.first?.message.content else {
            throw AIError.serverError(-2)
        }
        return content
    }

    func clear() {
        messages.removeAll()
    }
}
