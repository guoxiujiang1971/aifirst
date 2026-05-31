import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var hotkeyService: HotkeyService
    @EnvironmentObject var loc: LocalizationService

    var body: some View {
        Button {
            AppServices.appDelegate?.showChatWindow(text: "")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            let shortcut = shortcutDisplayString()
            if shortcut.isEmpty {
                Text(verbatim: loc.tr("menu_open_ai_chat"))
            } else {
                Text(verbatim: "\(loc.tr("menu_open_ai_chat"))  \(shortcut)")
            }
        }

        Divider()

        Button(loc.tr("menu_settings")) {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button(loc.tr("menu_quit")) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func shortcutDisplayString() -> String {
        let mods = modifierDisplaySymbols(UInt32(settings.hotkeyCarbonMods))
        let key = keyCodeDisplayString(UInt16(settings.hotkeyKeyCode))
        if mods.isEmpty { return key }
        return mods.joined() + key
    }
}
