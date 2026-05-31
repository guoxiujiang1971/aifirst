import SwiftUI

class AppSettings: ObservableObject {
    @Published var configs: [APIConfig] = [] {
        didSet { save() }
    }

    @Published var customActions: [CustomAction] = [] {
        didSet { save() }
    }

    @AppStorage("hotkey_key_code") var hotkeyKeyCode = 47
    @AppStorage("hotkey_carbon_mods") var hotkeyCarbonMods = 2304

    @AppStorage("qa_hotkey_key_code") var qaHotkeyKeyCode = 37
    @AppStorage("qa_hotkey_carbon_mods") var qaHotkeyCarbonMods = 2304

    @AppStorage("chat_font_size") var chatFontSize: Double = 14
    @AppStorage("chat_font_family") var chatFontFamily: String = "system"
    @AppStorage("appearance_mode") var appearanceMode: String = "system"
    @AppStorage("translation_source_lang") var translationSourceLang: String = "auto"
    @AppStorage("translation_target_lang") var translationTargetLang: String = "Chinese"

    var activeConfig: APIConfig? { configs.first(where: { $0.isEnabled }) }
    var baseURL: String { activeConfig?.baseURL ?? "" }
    var model: String { activeConfig?.model ?? "" }
    var apiKey: String { activeConfig?.apiKey ?? "" }
    var temperature: Double { activeConfig?.temperature ?? 0.7 }
    var maxTokens: Int { activeConfig?.maxTokens ?? 2048 }

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: "api_configs"),
           let configs = try? JSONDecoder().decode([APIConfig].self, from: data) {
            self.configs = configs
        } else {
            migrateFromOldStorage()
        }
        if let data = UserDefaults.standard.data(forKey: "custom_actions"),
           let actions = try? JSONDecoder().decode([CustomAction].self, from: data) {
            self.customActions = actions
        }
    }

    private func migrateFromOldStorage() {
        let oldURL = UserDefaults.standard.string(forKey: "base_url") ?? ""
        let oldModel = UserDefaults.standard.string(forKey: "model") ?? ""
        let oldKey = UserDefaults.standard.string(forKey: "api_key") ?? ""
        let oldTemp = UserDefaults.standard.double(forKey: "temperature")
        let oldTokens = UserDefaults.standard.integer(forKey: "max_tokens")

        if !oldURL.isEmpty || !oldKey.isEmpty {
            configs = [APIConfig(
                name: "Default Config",
                baseURL: oldURL.isEmpty ? "https://api.deepseek.com" : oldURL,
                model: oldModel.isEmpty ? "deepseek-chat" : oldModel,
                apiKey: oldKey,
                temperature: oldTemp != 0 ? oldTemp : 0.7,
                maxTokens: oldTokens != 0 ? oldTokens : 2048,
                isEnabled: true
            )]
        } else {
            configs = [
                APIConfig(name: "DeepSeek", baseURL: "https://api.deepseek.com", model: "deepseek-chat", isEnabled: true),
                APIConfig(name: "Ollama", baseURL: "http://localhost:11434", model: "llama3.2", isEnabled: false),
            ]
        }
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: "api_configs")
        }
        if let data = try? JSONEncoder().encode(customActions) {
            UserDefaults.standard.set(data, forKey: "custom_actions")
        }
    }

    func enable(_ id: UUID) {
        for i in configs.indices {
            configs[i].isEnabled = configs[i].id == id
        }
    }

    func delete(_ id: UUID) {
        let wasEnabled = configs.first(where: { $0.id == id })?.isEnabled ?? false
        configs.removeAll { $0.id == id }
        if wasEnabled, let _ = configs.first {
            configs[0].isEnabled = true
        }
    }

    func update(_ config: APIConfig) {
        guard let i = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[i] = config
    }

    func add(_ config: APIConfig) {
        configs.append(config)
    }

    func addCustomAction(_ action: CustomAction) {
        customActions.append(action)
    }

    func updateCustomAction(_ action: CustomAction) {
        guard let i = customActions.firstIndex(where: { $0.id == action.id }) else { return }
        customActions[i] = action
    }

    func deleteCustomAction(_ id: UUID) {
        customActions.removeAll { $0.id == id }
    }
}
