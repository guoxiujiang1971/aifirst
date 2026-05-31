import Cocoa
import Carbon

// MARK: - Key Code Display Helpers

func keyCodeDisplayString(_ code: UInt16) -> String {
    switch Int(code) {
    case 0: return "A"
    case 1: return "S"
    case 2: return "D"
    case 3: return "F"
    case 4: return "H"
    case 5: return "G"
    case 6: return "Z"
    case 7: return "X"
    case 8: return "C"
    case 9: return "V"
    case 11: return "B"
    case 12: return "Q"
    case 13: return "W"
    case 14: return "E"
    case 15: return "R"
    case 16: return "Y"
    case 17: return "T"
    case 18: return "1"
    case 19: return "2"
    case 20: return "3"
    case 21: return "4"
    case 22: return "6"
    case 23: return "5"
    case 24: return "="
    case 25: return "0"
    case 26: return "7"
    case 27: return "-"
    case 28: return "8"
    case 29: return "9"
    case 31: return "O"
    case 33: return "]"
    case 34: return "I"
    case 35: return "P"
    case 36: return "Return"
    case 37: return "L"
    case 38: return "J"
    case 39: return "'"
    case 40: return "K"
    case 41: return ";"
    case 42: return "?"
    case 43: return ","
    case 44: return "/"
    case 45: return "N"
    case 46: return "M"
    case 47: return "."
    case 48: return "Tab"
    case 49: return "Space"
    case 50: return "`"
    case 51: return "Delete"
    case 53: return "Escape"
    case kVK_Space: return "Space"
    case kVK_Return: return "Return"
    case kVK_Tab: return "Tab"
    case kVK_Escape: return "Esc"
    case kVK_Delete: return "Delete"
    case kVK_ForwardDelete: return "Forward Delete"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_DownArrow: return "↓"
    case kVK_UpArrow: return "↑"
    case kVK_Home: return "Home"
    case kVK_End: return "End"
    case kVK_PageUp: return "Page Up"
    case kVK_PageDown: return "Page Down"
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    default: return "Key(\(code))"
    }
}

func modifierDisplaySymbols(_ flags: UInt32) -> [String] {
    var s: [String] = []
    if flags & UInt32(controlKey) != 0 { s.append("⌃") }
    if flags & UInt32(optionKey) != 0 { s.append("⌥") }
    if flags & UInt32(shiftKey) != 0 { s.append("⇧") }
    if flags & UInt32(cmdKey) != 0 { s.append("⌘") }
    return s
}

func cgFlagsToCarbonMods(_ flags: CGEventFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.maskControl) { m |= UInt32(controlKey) }
    if flags.contains(.maskAlternate) { m |= UInt32(optionKey) }
    if flags.contains(.maskShift) { m |= UInt32(shiftKey) }
    if flags.contains(.maskCommand) { m |= UInt32(cmdKey) }
    return m
}

// MARK: - Hotkey Service

class HotkeyService: ObservableObject {
    private var hotkeyID: UInt32 = 0

    @Published var isEnabled = false
    @Published var needsPermission = false

    var onTrigger: (() -> Void)?

    var keyCode: UInt32 = 49
    var modifiers: UInt32 = UInt32(optionKey)

    func setShortcut(keyCode: UInt16, modifiers: CGEventFlags) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = cgFlagsToCarbonMods(modifiers)
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
                print("[HotkeyService] Callback fired, self=\(self != nil), onTrigger=\(self?.onTrigger != nil)")
                self?.onTrigger?()
            }
            self.isEnabled = self.hotkeyID != 0
            print("[HotkeyService] register status=\(self.hotkeyID != 0)")
        }
    }

    func unregister() {
        if hotkeyID != 0 {
            HotkeyManager.shared.unregister(id: hotkeyID)
            hotkeyID = 0
        }
        isEnabled = false
    }

    deinit { unregister() }
}