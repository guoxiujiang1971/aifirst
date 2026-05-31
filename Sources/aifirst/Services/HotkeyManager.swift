import Cocoa
import Carbon

func nsModifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.control) { m |= UInt32(controlKey) }
    if flags.contains(.option) { m |= UInt32(optionKey) }
    if flags.contains(.shift) { m |= UInt32(shiftKey) }
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    return m
}

class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private let signature: UInt32 = 1094869280
    private var eventHandler: EventHandlerRef?
    private var eventHandlerInstalled = false

    private init() {}

    private func ensureEventHandler() -> Bool {
        if eventHandlerInstalled { return true }
        return installEventHandler()
    }

    private func installEventHandler() -> Bool {
        let eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
                var hkid = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkid
                )
                if err != noErr { return err }
                print("[HotkeyManager] HotKeyPressed id=\(hkid.id)")
                if let cb = manager.callbacks[hkid.id] {
                    DispatchQueue.main.async { cb() }
                }
                return noErr
            } as EventHandlerUPP,
            1,
            [eventSpec],
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        if status == noErr {
            eventHandler = handlerRef
            eventHandlerInstalled = true
            print("[HotkeyManager] Event handler installed")
            return true
        }
        print("[HotkeyManager] InstallEventHandler failed: \(status)")
        return false
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) -> UInt32 {
        guard ensureEventHandler() else {
            print("[HotkeyManager] Cannot register hotkey: event handler not installed")
            return 0
        }
        var hotKeyRef: EventHotKeyRef?
        var hkid = EventHotKeyID()
        hkid.signature = signature
        hkid.id = nextID
        let status = RegisterEventHotKey(keyCode, modifiers, hkid, GetApplicationEventTarget(), 0, &hotKeyRef)
        print("[HotkeyManager] Register keyCode=\(keyCode) modifiers=\(modifiers) id=\(nextID) status=\(status)")
        if status == noErr, let ref = hotKeyRef {
            callbacks[nextID] = callback
            hotKeyRefs[nextID] = ref
            nextID += 1
            return nextID - 1
        }
        return 0
    }

    func unregister(id: UInt32) {
        guard let ref = hotKeyRefs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        callbacks.removeValue(forKey: id)
        print("[HotkeyManager] Unregistered id=\(id)")
    }

    func unregisterAll() {
        for (id, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
            callbacks.removeValue(forKey: id)
        }
        hotKeyRefs.removeAll()
        callbacks.removeAll()
    }

    deinit {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}
