import Cocoa
import Carbon
import SwiftUI

enum QuickAction: String, CaseIterable {
    case translate = "翻译"
    case polish = "润色"
    case summarize = "总结"
    case explainCode = "解释代码"
    case expand = "扩写"

    var localizationKey: String {
        switch self {
        case .translate: return "action_translate"
        case .polish: return "action_polish"
        case .summarize: return "action_summarize"
        case .explainCode: return "action_explain_code"
        case .expand: return "action_expand"
        }
    }

    func prompt(for text: String) -> String {
        switch self {
        case .translate:
            let s = AppServices.settings
            let src = s?.translationSourceLang ?? "auto"
            let tgt = s?.translationTargetLang ?? "Chinese"
            if src == "auto" {
                return "Translate the following text to \(tgt). Detect the source language automatically. Only return the translated text, no explanations."
            } else {
                return "Translate the following text from \(src) to \(tgt). Only return the translated text, no explanations."
            }
        case .polish:
            return "Polish the following text to make it more fluent and professional. Keep the original meaning and language. Only return the polished result, no explanations."
        case .summarize:
            return "Summarize the core content of the following text in concise language, using the same language as the input. Only return the summary."
        case .explainCode:
            return "Explain the functionality and implementation principles of the following code. Use the same language as the code comments or the input text."
        case .expand:
            return "Expand the following text by adding more details while preserving the original meaning and language. Make the expression richer and more complete. Only return the expanded result."
        }
    }
}

class QuickActionService: ObservableObject {
    private var hotkeyID: UInt32 = 0
    private let settings: AppSettings
    private let aiService: AIService

    @Published var selectedText = ""
    @Published var editableText = ""
    @Published var result = ""
    @Published var isProcessing = false
    @Published var currentAction: String?
    @Published var currentActionIsTranslate = false
    @Published var errorMessage: String?
    @Published var isPanelVisible = false
    @Published var isEnabled = false
    @Published var customActions: [CustomAction] = []

    var keyCode: UInt32 = 37
    var modifiers: UInt32 = 2304

    var builtInActions: [QuickAction] { QuickAction.allCases }

    private var servicesObserver: NSObjectProtocol?

    init(settings: AppSettings, aiService: AIService) {
        self.settings = settings
        self.aiService = aiService
        self.customActions = settings.customActions
        startObservingServices()
    }

    private func startObservingServices() {
        servicesObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("QuickActionService"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self,
                  let text = note.userInfo?["text"] as? String,
                  let actionRaw = note.userInfo?["action"] as? String else { return }
            self.selectedText = text
            self.editableText = text
            self.showPanel()
            if let builtIn = QuickAction(rawValue: actionRaw) {
                self.performAction(name: builtIn.rawValue, systemPrompt: builtIn.prompt(for: editableText), userPrompt: "")
            } else if let custom = self.customActions.first(where: { $0.name == actionRaw }) {
                self.performAction(name: custom.name, systemPrompt: custom.systemPrompt, userPrompt: custom.userPrompt)
            }
        }
    }

    func setShortcut(keyCode: UInt16, carbonModifiers: UInt32) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = carbonModifiers
    }

    func register() {
        unregister()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hotkeyID = HotkeyManager.shared.register(keyCode: self.keyCode, modifiers: self.modifiers) { [weak self] in
                print("[QuickActionService] Callback fired, self=\(self != nil)")
                self?.trigger()
            }
            self.isEnabled = self.hotkeyID != 0
            print("[QuickActionService] register status=\(self.hotkeyID != 0)")
        }
    }

    func unregister() {
        if hotkeyID != 0 {
            HotkeyManager.shared.unregister(id: hotkeyID)
            hotkeyID = 0
        }
        isEnabled = false
    }

    func trigger() {
        if isPanelVisible {
            AppServices.appDelegate?.showQuickActionWindow()
            return
        }

        errorMessage = nil
        result = ""
        isProcessing = false
        currentAction = nil
        currentActionIsTranslate = false

        captureSelectedText { text in
            guard !text.isEmpty else {
                self.errorMessage = AXIsProcessTrusted()
                    ? LocalizationService.shared.tr("qa_no_text")
                    : LocalizationService.shared.tr("qa_no_text_accessibility")
                self.showPanel()
                return
            }
            self.selectedText = text
            self.editableText = text
            self.showPanel()
        }
    }

    private func captureSelectedText(completion: @escaping (String) -> Void) {
        if !AXIsProcessTrusted() {
            Self.requestAccessibilityPermission()
        }

        // Primary: try Accessibility API to get selected text
        if AXIsProcessTrusted() {
            if let text = accessibilitySelectedText(), !text.isEmpty {
                completion(text)
                return
            }
        }

        // Fallback: send Cmd+C to the frontmost app via CGEvent.postToPid.
        let pasteboardBefore = NSPasteboard.general.string(forType: .string)

        if let app = NSWorkspace.shared.frontmostApplication {
            let pid = app.processIdentifier
            let src = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
            down?.flags = .maskCommand
            down?.postToPid(pid)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
            up?.flags = .maskCommand
            up?.postToPid(pid)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let current = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if current != (pasteboardBefore ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
                completion(current)
            } else if AXIsProcessTrusted(), let text = self.accessibilitySelectedText(), !text.isEmpty {
                completion(text)
            } else {
                completion("")
            }
        }
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilityPreferences() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    static func accessibilitySelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, "AXFocusedApplication" as CFString, &focusedApp) == .success,
              let app = focusedApp else { return nil }
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, "AXFocusedUIElement" as CFString, &focusedElement) == .success,
              let element = focusedElement else { return nil }
        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, "AXSelectedText" as CFString, &selectedText) == .success,
              let text = selectedText as? String, !text.isEmpty else { return nil }
        return text
    }

    func accessibilitySelectedText() -> String? {
        Self.accessibilitySelectedText()
    }

    func showPanel() {
        isPanelVisible = true
        if let delegate = AppServices.appDelegate {
            delegate.showQuickActionWindow()
        }
    }

    func hidePanel() {
        isPanelVisible = false
        if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "quickAction" }) {
            w.close()
        }
        result = ""
        currentAction = nil
        isProcessing = false
        errorMessage = nil
    }

    func performAction(_ action: QuickAction) {
        currentActionIsTranslate = action == .translate
        let prompt = action.prompt(for: editableText)
        performAction(name: LocalizationService.shared.tr(action.localizationKey), systemPrompt: prompt, userPrompt: "")
    }

    func performAction(name: String, systemPrompt: String, userPrompt: String) {
        currentAction = name
        isProcessing = true
        result = ""
        errorMessage = nil

        Task {
            do {
                let r = try await aiService.quickAction(systemPrompt: systemPrompt, userPrompt: userPrompt, text: editableText)
                await MainActor.run {
                    self.result = r
                    self.isProcessing = false
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(r, forType: .string)
                }
            } catch {
                await MainActor.run {
                    self.result = ""
                    self.errorMessage = "\(LocalizationService.shared.tr("qa_error")): \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    func addCustomAction(_ action: CustomAction) {
        customActions.append(action)
        settings.customActions = customActions
    }

    func deleteCustomAction(_ id: UUID) {
        customActions.removeAll { $0.id == id }
        settings.customActions = customActions
    }

    func replaceSelectedText() {
        guard !result.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

}
