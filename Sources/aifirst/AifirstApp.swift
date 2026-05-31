import SwiftUI
import Combine

enum AppServices {
    static var settings: AppSettings?
    static var aiService: AIService?
    static var quickActionService: QuickActionService?
    static weak var appDelegate: AppDelegate?
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyService = HotkeyService()
    var settings: AppSettings?
    var aiService: AIService?
    var quickActionService: QuickActionService?
    private var chatWindow: NSWindow?
    private var qaWindow: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = self

        AppServices.appDelegate = self
        settings = AppServices.settings
        aiService = AppServices.aiService
        quickActionService = AppServices.quickActionService

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let w = note.object as? NSWindow else { return }
            if w.title == "设置" || w.title == "Settings" {
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenChatWindow"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let text = note.userInfo?["text"] as? String ?? ""
            self?.showChatWindow(text: text)
        }

        let s = settings ?? AppSettings()
        hotkeyService.setShortcut(keyCode: UInt16(s.hotkeyKeyCode), carbonModifiers: UInt32(s.hotkeyCarbonMods))

        hotkeyService.onTrigger = {
            if AXIsProcessTrusted() {
                if let text = QuickActionService.accessibilitySelectedText(), !text.isEmpty {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenChatWindow"), object: nil, userInfo: ["text": text])
                    return
                }
            } else {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                AXIsProcessTrustedWithOptions(options as CFDictionary)
            }

            // Fallback: send Cmd+C to the frontmost app via CGEvent.postToPid.
            // Needed because some apps (e.g., Chrome) don't expose AXSelectedText via Accessibility API.
            // Uses postToPid (targeted to a specific process), NOT post(tap:) (global HID injection).
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
                let current = NSPasteboard.general.string(forType: .string) ?? ""
                if current != (pasteboardBefore ?? "") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenChatWindow"), object: nil, userInfo: ["text": current])
                } else if AXIsProcessTrusted(), let axText = QuickActionService.accessibilitySelectedText(), !axText.isEmpty {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenChatWindow"), object: nil, userInfo: ["text": axText])
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenChatWindow"), object: nil, userInfo: ["text": ""])
                }
            }
        }
        hotkeyService.register()
        quickActionService?.register()

        // Apply saved appearance mode
        applyTheme(settings?.appearanceMode ?? "system")

        // Observe language changes to update window titles
        LocalizationService.shared.$_currentLanguage
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.chatWindow?.title = LocalizationService.shared.tr("chat_title")
                self.qaWindow?.title = LocalizationService.shared.tr("qa_title")
            }
            .store(in: &cancellables)

        // Observe appearance mode changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let mode = UserDefaults.standard.string(forKey: "appearance_mode") ?? "system"
                self?.applyTheme(mode)
            }
            .store(in: &cancellables)
    }

    private func applyTheme(_ mode: String) {
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func showChatWindow(text: String) {
        if let w = chatWindow {
            w.makeKeyAndOrderFront(nil)
        } else {
            guard let settings = settings, let aiService = aiService else { return }
            let view = ChatPanelView()
                .environmentObject(settings)
                .environmentObject(aiService)
                .environmentObject(LocalizationService.shared)
            let hostingCtrl = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hostingCtrl)
            w.identifier = NSUserInterfaceItemIdentifier("chat")
            w.title = LocalizationService.shared.tr("chat_title")
            w.setContentSize(NSSize(width: 480, height: 640))
            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            chatWindow = w
            w.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)

        if !text.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("ChatInputText"), object: nil, userInfo: ["text": text])
            }
        }
    }

    func showQuickActionWindow() {
        if let w = qaWindow {
            w.makeKeyAndOrderFront(nil)
        } else {
            guard let qa = quickActionService else { return }
            let view = QuickActionPanelView()
                .environmentObject(qa)
                .environmentObject(LocalizationService.shared)
                .environmentObject(settings ?? AppSettings())
            let hostingCtrl = NSHostingController(rootView: view)
            let w = NSWindow(contentViewController: hostingCtrl)
            w.identifier = NSUserInterfaceItemIdentifier("quickAction")
            w.title = LocalizationService.shared.tr("qa_title")
            w.setContentSize(NSSize(width: 400, height: 420))
            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            qaWindow = w
            w.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - macOS Services

    @objc func aiTranslate(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard: pboard, action: "翻译")
    }

    @objc func aiPolish(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard: pboard, action: "润色")
    }

    @objc func aiSummarize(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard: pboard, action: "总结")
    }

    @objc func aiExplainCode(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        handleService(pboard: pboard, action: "解释代码")
    }

    private func handleService(pboard: NSPasteboard, action: String) {
        guard let text = pboard.string(forType: .string) else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickActionService"),
                object: nil,
                userInfo: ["text": text, "action": action]
            )
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        if w.identifier?.rawValue == "chat" {
            chatWindow = nil
        } else if w.identifier?.rawValue == "quickAction" {
            qaWindow = nil
            quickActionService?.isPanelVisible = false
        }
    }
}

@main
struct AifirstApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var aiService: AIService
    @StateObject private var quickActionService: QuickActionService

    init() {
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        let ai = AIService(settings: s)
        _aiService = StateObject(wrappedValue: ai)
        let qa = QuickActionService(settings: s, aiService: ai)
        qa.setShortcut(keyCode: UInt16(s.qaHotkeyKeyCode), carbonModifiers: UInt32(s.qaHotkeyCarbonMods))
        _quickActionService = StateObject(wrappedValue: qa)

        AppServices.settings = s
        AppServices.aiService = ai
        AppServices.quickActionService = qa
    }

    var body: some Scene {
        MenuBarExtra(LocalizationService.shared.tr("app_name"), systemImage: "brain") {
            MenuBarView()
                .environmentObject(settings)
                .environmentObject(appDelegate.hotkeyService)
                .environmentObject(LocalizationService.shared)
                .onAppear {
                    appDelegate.settings = AppServices.settings
                    appDelegate.aiService = AppServices.aiService
                    appDelegate.quickActionService = AppServices.quickActionService
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(appDelegate.hotkeyService)
                .environmentObject(quickActionService)
                .environmentObject(LocalizationService.shared)
                .id(LocalizationService.shared.currentLanguage)
        }
    }
}
