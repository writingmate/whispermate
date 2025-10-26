import AppKit
internal import Combine

class HotkeyManager: ObservableObject {
    @Published var currentHotkey: Hotkey?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyUpMonitor: Any?
    private var previousFunctionKeyState = false
    private var fnKeyMonitor: FnKeyMonitor?
    private var deferRegistration = false

    // Double-tap detection
    private var lastTapTime: Date?
    private let doubleTapInterval: TimeInterval = 0.3 // 300ms
    private var isHoldingKey = false

    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var onDoubleTap: (() -> Void)?

    init() {
        loadHotkey()
    }

    func setDeferRegistration(_ shouldDefer: Bool) {
        deferRegistration = shouldDefer
        if !shouldDefer && currentHotkey != nil {
            // Registration was deferred but now enabled - register the hotkey
            registerHotkey()
        }
    }

    func setHotkey(_ hotkey: Hotkey) {
        currentHotkey = hotkey
        saveHotkey()

        // Only register if not deferred
        if !deferRegistration {
            registerHotkey()
        }
    }

    func clearHotkey() {
        currentHotkey = nil
        UserDefaults.standard.removeObject(forKey: "hotkey_keycode")
        UserDefaults.standard.removeObject(forKey: "hotkey_modifiers")
        unregisterHotkey()
    }

    private func loadHotkey() {
        guard let keyCode = UserDefaults.standard.value(forKey: "hotkey_keycode") as? UInt16,
              let modifiers = UserDefaults.standard.value(forKey: "hotkey_modifiers") as? UInt else {
            return
        }

        currentHotkey = Hotkey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers))
        registerHotkey()
    }

    private func saveHotkey() {
        guard let hotkey = currentHotkey else { return }
        UserDefaults.standard.set(hotkey.keyCode, forKey: "hotkey_keycode")
        UserDefaults.standard.set(hotkey.modifiers.rawValue, forKey: "hotkey_modifiers")
    }

    private var flagsMonitor: Any?

    private func registerHotkey() {
        guard let hotkey = currentHotkey else {
            print("[HotkeyManager LOG] registerHotkey: No hotkey configured")
            unregisterHotkey()
            return
        }

        print("[HotkeyManager LOG] registerHotkey: keyCode=\(hotkey.keyCode), modifiers=\(hotkey.modifiers.rawValue)")
        print("[HotkeyManager LOG] registerHotkey: displayString=\(hotkey.displayString)")

        // If the Fn monitor is already running for the same hotkey, don't restart it
        if hotkey.modifiers == .function && hotkey.keyCode == 63 && fnKeyMonitor != nil {
            print("[HotkeyManager LOG] Fn key monitor already running, skipping re-registration")
            return
        }

        unregisterHotkey()

        // If hotkey is just Fn key, use polling-based monitoring
        if hotkey.modifiers == .function && hotkey.keyCode == 63 {
            print("[HotkeyManager LOG] ========================================")
            print("[HotkeyManager LOG] Using Fn-only path (POLLING mode)")
            print("[HotkeyManager LOG] This works globally, even in background!")
            print("[HotkeyManager LOG] Creating FnKeyMonitor...")

            // Use polling-based Fn key monitor
            fnKeyMonitor = FnKeyMonitor()
            print("[HotkeyManager LOG] FnKeyMonitor created")
            print("[HotkeyManager LOG] Setting up onFnPressed callback...")
            fnKeyMonitor?.onFnPressed = { [weak self] in
                print("[HotkeyManager LOG] 🔥 Fn key pressed (polling) - calling onHotkeyPressed 🔥")
                self?.onHotkeyPressed?()
                print("[HotkeyManager LOG] onHotkeyPressed callback returned")
            }
            print("[HotkeyManager LOG] Setting up onFnReleased callback...")
            fnKeyMonitor?.onFnReleased = { [weak self] in
                print("[HotkeyManager LOG] 🔥 Fn key released (polling) - calling onHotkeyReleased 🔥")
                self?.onHotkeyReleased?()
                print("[HotkeyManager LOG] onHotkeyReleased callback returned")
            }
            print("[HotkeyManager LOG] Callbacks configured, starting monitoring...")
            fnKeyMonitor?.startMonitoring()
            print("[HotkeyManager LOG] ========================================")
        } else {
            print("[HotkeyManager LOG] Using regular key path (keyDown + keyUp events)")
            print("[HotkeyManager LOG] Registering global and local monitors for keyDown and keyUp")

            // Monitor keyDown events
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                print("[HotkeyManager LOG] Global keyDown monitor triggered")
                self?.handleKeyDownEvent(event)
            }

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                print("[HotkeyManager LOG] Local keyDown monitor triggered")
                if self?.handleKeyDownEvent(event) == true {
                    return nil // Consume the event
                }
                return event
            }

            // Monitor keyUp events
            keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
                print("[HotkeyManager LOG] Local keyUp monitor triggered")
                if self?.handleKeyUpEvent(event) == true {
                    return nil // Consume the event
                }
                return event
            }
        }
    }

    private func unregisterHotkey() {
        print("[HotkeyManager LOG] unregisterHotkey called")
        if let monitor = globalMonitor {
            print("[HotkeyManager LOG] Removing global monitor")
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            print("[HotkeyManager LOG] Removing local monitor")
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = keyUpMonitor {
            print("[HotkeyManager LOG] Removing keyUp monitor")
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }

        if let fnMonitor = fnKeyMonitor {
            print("[HotkeyManager LOG] Stopping Fn key monitor")
            fnMonitor.stopMonitoring()
            fnKeyMonitor = nil
        }

        previousFunctionKeyState = false
    }

    @discardableResult
    private func handleKeyDownEvent(_ event: NSEvent) -> Bool {
        guard let hotkey = currentHotkey else { return false }

        print("[HotkeyManager LOG] handleKeyDownEvent: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue), isARepeat=\(event.isARepeat)")

        // Ignore key repeat events
        if event.isARepeat {
            print("[HotkeyManager LOG] handleKeyDownEvent: Ignoring key repeat event")
            return false
        }

        // Check if the key code and modifiers match
        if event.keyCode == hotkey.keyCode &&
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == hotkey.modifiers {

            // Check for double-tap
            let now = Date()
            if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < doubleTapInterval {
                print("[HotkeyManager LOG] handleKeyDownEvent: DOUBLE-TAP detected - calling onDoubleTap")
                lastTapTime = nil // Reset for next sequence
                isHoldingKey = false // Don't track as hold
                onDoubleTap?()
                return true
            }

            // Single tap - start hold-to-record
            print("[HotkeyManager LOG] handleKeyDownEvent: MATCH - calling onHotkeyPressed (START recording)")
            lastTapTime = now // Track this tap for potential double-tap
            isHoldingKey = true
            onHotkeyPressed?()
            return true
        }

        return false
    }

    @discardableResult
    private func handleKeyUpEvent(_ event: NSEvent) -> Bool {
        guard let hotkey = currentHotkey else { return false }

        print("[HotkeyManager LOG] handleKeyUpEvent: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)")

        // Check if the key code matches (modifiers may not be present on keyUp)
        if event.keyCode == hotkey.keyCode {
            // Only call onHotkeyReleased if we're in hold-to-record mode
            if isHoldingKey {
                print("[HotkeyManager LOG] handleKeyUpEvent: MATCH - calling onHotkeyReleased (STOP recording)")
                isHoldingKey = false
                onHotkeyReleased?()
            } else {
                print("[HotkeyManager LOG] handleKeyUpEvent: Key released but not in hold mode (continuous recording)")
            }
            return true
        }

        return false
    }

    deinit {
        unregisterHotkey()
    }
}

struct Hotkey: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    var displayString: String {
        // Special case: just Fn key alone
        if modifiers == .function && keyCode == 63 {
            return "Fn"
        }

        var parts: [String] = []

        if modifiers.contains(.function) {
            parts.append("Fn")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.command) {
            parts.append("⌘")
        }

        if let keyString = KeyCodeHelper.string(for: keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }
}

class KeyCodeHelper {
    static func string(for keyCode: UInt16) -> String? {
        switch keyCode {
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
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return nil
        }
    }
}
