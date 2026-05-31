import SwiftUI

struct QuickActionPanelView: View {
    @EnvironmentObject var service: QuickActionService
    @EnvironmentObject var loc: LocalizationService
    @EnvironmentObject var settings: AppSettings
    @State private var copied = false
    @State private var showAddCustom = false

    var body: some View {
        VStack(spacing: 12) {
            if let err = service.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !AXIsProcessTrusted() {
                        Button(loc.tr("qa_authorize")) {
                            QuickActionService.openAccessibilityPreferences()
                        }
                        .controlSize(.small)
                    }
                    Button(loc.tr("qa_close")) { service.hidePanel() }
                        .controlSize(.small)
                }
            }

            if !service.selectedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(verbatim: loc.tr("qa_edit_text"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        if service.currentActionIsTranslate {
                            Picker("", selection: Binding(
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
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                            .controlSize(.small)
                        }
                    }

                    TextEditor(text: $service.editableText)
                        .font(.body)
                        .frame(maxHeight: 120)
                        .frame(minHeight: 44)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3))
                        )
                }
            }

            if service.isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(verbatim: "\(service.currentAction ?? loc.tr("qa_processing"))...")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if !service.result.isEmpty {
                resultView
            } else {
                actionButtons
            }
        }
        .padding()
        .sheet(isPresented: $showAddCustom) {
            AddCustomActionView { action in
                service.addCustomAction(action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            guard let w = note.object as? NSWindow,
                  w.identifier?.rawValue == "quickAction" else { return }
            service.isPanelVisible = false
        }
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(service.currentAction ?? "结果")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if service.currentActionIsTranslate {
                    Picker("", selection: Binding(
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
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .controlSize(.small)
                }
            }

            ScrollView {
                Text(service.result)
                    .textSelection(.enabled)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)

            HStack(spacing: 8) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(service.result, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }) {
                    Label(copied ? loc.tr("qa_copied") : loc.tr("qa_copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)

                Spacer()

                Button(loc.tr("qa_close")) { service.hidePanel() }
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Text(verbatim: loc.tr("qa_select_action"))
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(service.builtInActions, id: \.self) { action in
                    Button(loc.tr(action.localizationKey)) {
                        service.performAction(action)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ForEach(service.customActions) { action in
                    Button(action.name) {
                        service.performAction(
                            name: action.name,
                            systemPrompt: action.systemPrompt,
                            userPrompt: action.userPrompt
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    showAddCustom = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 16)
    }
}

struct AddCustomActionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var loc: LocalizationService
    @State private var name = ""
    @State private var systemPrompt = ""
    @State private var userPrompt = ""
    let onSave: (CustomAction) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: loc.tr("custom_action_title"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: loc.tr("custom_action_name"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $name, prompt: Text(verbatim: loc.tr("custom_action_name")))
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: loc.tr("custom_action_system_prompt"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(height: 80)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: loc.tr("custom_action_user_prompt"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("", text: $userPrompt, prompt: Text(verbatim: loc.tr("custom_action_user_prompt")))
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button(loc.tr("custom_action_cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(loc.tr("custom_action_save")) {
                    let action = CustomAction(name: name, systemPrompt: systemPrompt, userPrompt: userPrompt)
                    onSave(action)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
