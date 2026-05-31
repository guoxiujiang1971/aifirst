import SwiftUI
import Carbon

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var hotkeyService: HotkeyService
    @EnvironmentObject var quickActionService: QuickActionService
    @EnvironmentObject var loc: LocalizationService
    @State private var showAddSheet = false
    @State private var expandedId: UUID?
    @State private var testingId: UUID?
    @State private var testResults: [UUID: String] = [:]

    var body: some View {
        TabView {
            configsTab
                .tabItem { Label { Text(verbatim: loc.tr("settings_tab_api")) } icon: { Image(systemName: "list.bullet") } }

            hotkeyTab
                .tabItem { Label { Text(verbatim: loc.tr("settings_tab_hotkeys")) } icon: { Image(systemName: "keyboard") } }

            languageTab
                .tabItem { Label { Text(verbatim: loc.tr("settings_tab_language")) } icon: { Image(systemName: "globe") } }
        }
        .frame(width: 540, height: 460)
        .sheet(isPresented: $showAddSheet, content: addConfigSheet)
    }

    // MARK: - API 配置列表

    private var configsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text(verbatim: loc.tr("settings_tab_api"))
                    .font(.headline)
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Label(loc.tr("settings_add"), systemImage: "plus")
                }
                .controlSize(.small)
            }
            .padding()

            Divider()

            if settings.configs.isEmpty {
                VStack(spacing: 8) {
                    Text(verbatim: loc.tr("settings_no_config"))
                        .foregroundColor(.secondary)
                    Button(loc.tr("settings_add_first_config")) { showAddSheet = true }
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(settings.configs.enumerated()), id: \.element.id) { i, config in
                            configCard(config: config, at: i)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func configCard(config: APIConfig, at index: Int) -> some View {
        let isExpanded = expandedId == config.id

        return VStack(spacing: 0) {
            headerView(config: config, isExpanded: isExpanded)

            if isExpanded {
                Divider().padding(.horizontal, 8)
                expandedForm(at: index)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(config.isEnabled ? Color.accentColor.opacity(0.04) : Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(config.isEnabled ? Color.green.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private func headerView(config: APIConfig, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            Button(action: { settings.enable(config.id) }) {
                Image(systemName: config.isEnabled ? "record.circle" : "circle")
                    .foregroundColor(config.isEnabled ? .green : .secondary)
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .help(config.isEnabled ? loc.tr("settings_currently_enabled") : loc.tr("settings_click_to_enable"))

            Text(config.name)
                .fontWeight(config.isEnabled ? .semibold : .regular)
                .lineLimit(1)

            Spacer()

            Text(verbatim: config.isEnabled ? loc.tr("settings_enabled") : "")
                .font(.caption)
                .foregroundColor(.green)
                .opacity(config.isEnabled ? 1 : 0)

            Button(action: {
                withAnimation { expandedId = isExpanded ? nil : config.id }
            }) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)

            Button(role: .destructive) {
                withAnimation { settings.delete(config.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func expandedForm(at index: Int) -> some View {
        let config = settings.configs[index]
        let binding = $settings.configs[index]

        return Form {
            TextField(loc.tr("settings_name"), text: binding.name)
                .textFieldStyle(.roundedBorder)

            SecureField(loc.tr("settings_api_key_placeholder"), text: binding.apiKey)
                .textFieldStyle(.roundedBorder)

            TextField(loc.tr("settings_api_url"), text: binding.baseURL)
                .textFieldStyle(.roundedBorder)

            TextField(loc.tr("settings_model"), text: binding.model)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(verbatim: loc.tr("settings_temperature") + String(format: "%.1f", config.temperature))
                Slider(value: binding.temperature, in: 0...2, step: 0.1)
            }

            HStack {
                Text(verbatim: loc.tr("settings_max_tokens"))
                Spacer()
                Text("\(config.maxTokens)")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40)
                Stepper("", value: binding.maxTokens, in: 256...16384, step: 256)
                    .labelsHidden()
            }

            HStack {
                if testingId == config.id {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(verbatim: loc.tr("settings_testing"))
                        .foregroundColor(.secondary)
                } else if let result = testResults[config.id] {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.hasPrefix("✅") ? .green : .red)
                }
                Spacer()
                Button(loc.tr("settings_test_connection")) {
                    runTest(at: index)
                }
                .controlSize(.small)
            }
        }
        .padding(.top, 8)
    }

    private func runTest(at index: Int) {
        let config = settings.configs[index]
        testingId = config.id
        testResults[config.id] = nil
        Task {
            let service = AIService(settings: settings)
            let result = await service.testConnection(for: config)
            await MainActor.run {
                testResults[config.id] = result
                testingId = nil
            }
        }
    }

    // MARK: - 添加配置

    @State private var newName = ""
    @State private var newURL = "https://api.deepseek.com"
    @State private var newModel = "deepseek-chat"
    @State private var newKey = ""

    private func addConfigSheet() -> some View {
        VStack(spacing: 0) {
            Text(verbatim: loc.tr("settings_add_api_config"))
                .font(.headline)
                .padding()

            Divider()

            Form {
                TextField(loc.tr("settings_name"), text: $newName)
                    .textFieldStyle(.roundedBorder)
                TextField(loc.tr("settings_api_url"), text: $newURL)
                    .textFieldStyle(.roundedBorder)
                TextField(loc.tr("settings_model"), text: $newModel)
                    .textFieldStyle(.roundedBorder)
                SecureField(loc.tr("settings_api_key"), text: $newKey)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Button(loc.tr("settings_cancel")) { showAddSheet = false }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button(loc.tr("settings_add")) {
                    let config = APIConfig(
                        name: newName.trimmingCharacters(in: .whitespaces).isEmpty ? loc.tr("settings_new_config") : newName,
                        baseURL: newURL,
                        model: newModel,
                        apiKey: newKey,
                        isEnabled: !settings.configs.contains(where: { $0.isEnabled })
                    )
                    settings.add(config)
                    showAddSheet = false
                    resetNewConfig()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 340)
    }

    private func resetNewConfig() {
        newName = ""
        newURL = "https://api.deepseek.com"
        newModel = "deepseek-chat"
        newKey = ""
    }

    // MARK: - 快捷键

    private var hotkeyTab: some View {
        Form {
            Section {
                Text(verbatim: loc.tr("hotkey_chat"))
                    .foregroundColor(.secondary)
                    .font(.caption)

                HotkeyRecorderView(
                    keyCode: $settings.hotkeyKeyCode,
                    carbonMods: $settings.hotkeyCarbonMods
                ) {
                    hotkeyService.setShortcut(
                        keyCode: UInt16(settings.hotkeyKeyCode),
                        carbonModifiers: UInt32(settings.hotkeyCarbonMods)
                    )
                    hotkeyService.register()
                }

                HStack {
                    if hotkeyService.needsPermission {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(verbatim: loc.tr("settings_accessibility_required"))
                            .foregroundColor(.secondary)
                    } else if hotkeyService.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(verbatim: loc.tr("settings_hotkey_registered"))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(verbatim: loc.tr("settings_hotkey_unregistered"))
                            .foregroundColor(.secondary)
                    }
                }

                if hotkeyService.needsPermission {
                    Text(verbatim: loc.tr("settings_accessibility_help"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section {
                Text(verbatim: loc.tr("settings_hotkey_help"))
                    .foregroundColor(.secondary)
                    .font(.caption)

                HotkeyRecorderView(
                    keyCode: $settings.qaHotkeyKeyCode,
                    carbonMods: $settings.qaHotkeyCarbonMods
                ) {
                    quickActionService.setShortcut(
                        keyCode: UInt16(settings.qaHotkeyKeyCode),
                        carbonModifiers: UInt32(settings.qaHotkeyCarbonMods)
                    )
                    quickActionService.register()
                }

                HStack {
                    if quickActionService.isEnabled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(verbatim: loc.tr("settings_hotkey_registered"))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text(verbatim: loc.tr("settings_hotkey_unregistered"))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(verbatim: loc.tr("settings_quick_actions"))
            }
        }
        .padding()
    }

    private var languageTab: some View {
        Form {
            Picker(selection: Binding(
                get: { loc.currentLanguage },
                set: { loc.currentLanguage = $0 }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(verbatim: lang.displayName).tag(lang)
                }
            } label: {
                Text(verbatim: loc.tr("settings_tab_language"))
            }

            Divider()

            HStack {
                Text(verbatim: "\(loc.tr("settings_font_size")): \(Int(settings.chatFontSize))")
                Spacer()
                Stepper("", value: $settings.chatFontSize, in: 10...24, step: 1)
                    .labelsHidden()
            }

            Picker(selection: Binding(
                get: { settings.chatFontFamily },
                set: { settings.chatFontFamily = $0 }
            )) {
                Text(verbatim: loc.tr("font_system")).tag("system")
                Text(verbatim: loc.tr("font_rounded")).tag("rounded")
                Text(verbatim: loc.tr("font_serif")).tag("serif")
                Text(verbatim: loc.tr("font_monospace")).tag("monospace")
            } label: {
                Text(verbatim: loc.tr("settings_chat_font"))
            }

            Divider()

            Picker(selection: Binding(
                get: { settings.appearanceMode },
                set: { settings.appearanceMode = $0 }
            )) {
                Text(verbatim: loc.tr("theme_system")).tag("system")
                Text(verbatim: loc.tr("theme_light")).tag("light")
                Text(verbatim: loc.tr("theme_dark")).tag("dark")
            } label: {
                Text(verbatim: loc.tr("settings_theme"))
            }

            Divider()

            Picker(selection: Binding(
                get: { settings.translationSourceLang },
                set: { settings.translationSourceLang = $0 }
            )) {
                Text(verbatim: loc.tr("lang_auto")).tag("auto")
                Text("English").tag("English")
                Text("中文").tag("中文")
                Text("日本語").tag("日本語")
                Text("한국어").tag("한국어")
                Text("Français").tag("Français")
                Text("Deutsch").tag("Deutsch")
                Text("Español").tag("Español")
                Text("Русский").tag("Русский")
            } label: {
                Text(verbatim: loc.tr("translation_source"))
            }

            Picker(selection: Binding(
                get: { settings.translationTargetLang },
                set: { settings.translationTargetLang = $0 }
            )) {
                Text("English").tag("English")
                Text("中文").tag("中文")
                Text("日本語").tag("日本語")
                Text("한국어").tag("한국어")
                Text("Français").tag("Français")
                Text("Deutsch").tag("Deutsch")
                Text("Español").tag("Español")
                Text("Русский").tag("Русский")
            } label: {
                Text(verbatim: loc.tr("translation_target"))
            }
        }
        .padding()
    }
}

// MARK: - Hotkey Recorder

struct HotkeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var carbonMods: Int
    var onSave: () -> Void
    @EnvironmentObject var loc: LocalizationService

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 170, height: 30)
                    .background(Color(.textBackgroundColor).cornerRadius(6))

                if isRecording {
                    Text(verbatim: loc.tr("hotkey_press"))
                        .foregroundColor(.accentColor)
                        .font(.caption)
                } else {
                    Text(currentShortcutDisplay)
                        .fontWeight(.medium)
                }
            }
            .onTapGesture { startRecording() }

            Button(isRecording ? loc.tr("hotkey_cancel") : loc.tr("hotkey_record")) {
                if isRecording { stopRecording() }
                else { startRecording() }
            }
            .controlSize(.small)

            Button(loc.tr("settings_apply")) {
                onSave()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
        }
    }

    private var currentShortcutDisplay: String {
        let sym = modifierDisplaySymbols(UInt32(carbonMods))
        let key = keyCodeDisplayString(UInt16(keyCode))
        return (sym + [key]).joined(separator: " + ")
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.monitor != nil else { return event }

            let carbon = nsModifiersToCarbon(event.modifierFlags)

            self.keyCode = Int(event.keyCode)
            self.carbonMods = Int(carbon)

            self.isRecording = false
            if let m = self.monitor {
                NSEvent.removeMonitor(m)
                self.monitor = nil
            }

            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}
