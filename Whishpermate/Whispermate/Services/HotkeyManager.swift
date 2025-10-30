import AppKit
internal import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var currentHotkey: Hotkey?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyUpMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var previousFunctionKeyState = false
    private var fnKeyMonitor: FnKeyMonitor?
    private var deferRegistration = false
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?

    // Double-tap detection
    private var lastTapTime: Date?
    private let doubleTapInterval: TimeInterval = 0.3 // 300ms
    private var isHoldingKey = false

    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?
    var onDoubleTap: (() -> Void)?

    private init() {
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
            DebugLog.info("registerHotkey: No hotkey configured", context: "HotkeyManager LOG")
            unregisterHotkey()
            return
        }

        DebugLog.info("registerHotkey: keyCode=\(hotkey.keyCode), modifiers=\(hotkey.modifiers.rawValue)", context: "HotkeyManager LOG")
        DebugLog.info("registerHotkey: displayString=\(hotkey.displayString)", context: "HotkeyManager LOG")

        // If the Fn monitor is already running for the same hotkey, don't restart it
        if hotkey.modifiers == .function && hotkey.keyCode == 63 && fnKeyMonitor != nil {
            DebugLog.info("Fn key monitor already running, skipping re-registration", context: "HotkeyManager LOG")
            return
        }

        unregisterHotkey()

        // If hotkey is just Fn key, use polling-based monitoring
        if hotkey.modifiers == .function && hotkey.keyCode == 63 {
            DebugLog.info("========================================", context: "HotkeyManager LOG")
            DebugLog.info("Using Fn-only path (POLLING mode)", context: "HotkeyManager LOG")
            DebugLog.info("This works globally, even in background!", context: "HotkeyManager LOG")
            DebugLog.info("Creating FnKeyMonitor...", context: "HotkeyManager LOG")

            // Use polling-based Fn key monitor
            fnKeyMonitor = FnKeyMonitor()
            DebugLog.info("FnKeyMonitor created", context: "HotkeyManager LOG")
            DebugLog.info("Setting up onFnPressed callback...", context: "HotkeyManager LOG")
            fnKeyMonitor?.onFnPressed = { [weak self] in
                DebugLog.info("🔥 Fn key pressed (polling) - calling onHotkeyPressed 🔥", context: "HotkeyManager LOG")
                self?.onHotkeyPressed?()
                DebugLog.info("onHotkeyPressed callback returned", context: "HotkeyManager LOG")
            }
            DebugLog.info("Setting up onFnReleased callback...", context: "HotkeyManager LOG")
            fnKeyMonitor?.onFnReleased = { [weak self] in
                DebugLog.info("🔥 Fn key released (polling) - calling onHotkeyReleased 🔥", context: "HotkeyManager LOG")
                self?.onHotkeyReleased?()
                DebugLog.info("onHotkeyReleased callback returned", context: "HotkeyManager LOG")
            }
            DebugLog.info("Callbacks configured, starting monitoring...", context: "HotkeyManager LOG")
            fnKeyMonitor?.startMonitoring()
            DebugLog.info("========================================", context: "HotkeyManager LOG")
        } else {
            DebugLog.info("Using regular key path with CGEventTap for global consumption", context: "HotkeyManager LOG")

            // Use CGEventTap which can consume events even when app is in background
            // This requires accessibility permissions, which we request during onboarding
            setupEventTap()
        }
    }

    private func setupEventTap() {
        // Create event tap that intercepts key events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        // Capture self in the callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            DebugLog.info("Failed to create event tap - accessibility permission may not be granted", context: "HotkeyManager LOG")
            return
        }

        eventTap = tap
        eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), eventTapRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        DebugLog.info("Event tap created and enabled", context: "HotkeyManager LOG")
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard currentHotkey != nil else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            // Create NSEvent for compatibility with existing handler
            if let nsEvent = NSEvent(cgEvent: event) {
                let shouldConsume = handleKeyDownEvent(nsEvent)
                if shouldConsume {
                    return nil // Consume the event
                }
            }
        } else if type == .keyUp {
            // Create NSEvent for compatibility with existing handler
            if let nsEvent = NSEvent(cgEvent: event) {
                let shouldConsume = handleKeyUpEvent(nsEvent)
                if shouldConsume {
                    return nil // Consume the event
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func unregisterHotkey() {
        DebugLog.info("unregisterHotkey called", context: "HotkeyManager LOG")

        // Disable and remove event tap
        if let tap = eventTap {
            DebugLog.info("Disabling event tap", context: "HotkeyManager LOG")
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = eventTapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                eventTapRunLoopSource = nil
            }
            eventTap = nil
        }

        if let monitor = globalMonitor {
            DebugLog.info("Removing global monitor", context: "HotkeyManager LOG")
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            DebugLog.info("Removing local monitor", context: "HotkeyManager LOG")
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalKeyUpMonitor {
            DebugLog.info("Removing global keyUp monitor", context: "HotkeyManager LOG")
            NSEvent.removeMonitor(monitor)
            globalKeyUpMonitor = nil
        }

        if let monitor = keyUpMonitor {
            DebugLog.info("Removing keyUp monitor", context: "HotkeyManager LOG")
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }

        if let fnMonitor = fnKeyMonitor {
            DebugLog.info("Stopping Fn key monitor", context: "HotkeyManager LOG")
            fnMonitor.stopMonitoring()
            fnKeyMonitor = nil
        }

        previousFunctionKeyState = false
    }

    @discardableResult
    private func handleKeyDownEvent(_ event: NSEvent) -> Bool {
        guard let hotkey = currentHotkey else { return false }

        DebugLog.info("handleKeyDownEvent: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue), isARepeat=\(event.isARepeat)", context: "HotkeyManager LOG")

        // Consume key repeat events to prevent typing sounds
        if event.isARepeat {
            DebugLog.info("handleKeyDownEvent: Ignoring key repeat event", context: "HotkeyManager LOG")
            // Return true if this is our hotkey to consume the repeat event
            return event.keyCode == hotkey.keyCode
        }

        // Check if the key code matches and required modifiers are present
        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let requiredModifiers = hotkey.modifiers

        // For hotkeys with modifiers, check if all required modifiers are present
        // For hotkeys without modifiers, check for exact match (no modifiers)
        let modifiersMatch: Bool
        if requiredModifiers.isEmpty {
            modifiersMatch = eventModifiers.isEmpty
        } else {
            modifiersMatch = eventModifiers.intersection(requiredModifiers) == requiredModifiers
        }

        if event.keyCode == hotkey.keyCode && modifiersMatch {

            // Check for double-tap
            let now = Date()
            if let lastTap = lastTapTime, now.timeIntervalSince(lastTap) < doubleTapInterval {
                DebugLog.info("handleKeyDownEvent: DOUBLE-TAP detected - calling onDoubleTap", context: "HotkeyManager LOG")
                lastTapTime = nil // Reset for next sequence
                isHoldingKey = false // Don't track as hold
                onDoubleTap?()
                return true
            }

            // Single tap - start hold-to-record
            DebugLog.info("handleKeyDownEvent: MATCH - calling onHotkeyPressed (START recording)", context: "HotkeyManager LOG")
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

        DebugLog.info("handleKeyUpEvent: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags.rawValue)", context: "HotkeyManager LOG")

        // Check if the key code matches (modifiers may not be present on keyUp)
        if event.keyCode == hotkey.keyCode {
            // Only call onHotkeyReleased if we're in hold-to-record mode
            if isHoldingKey {
                DebugLog.info("handleKeyUpEvent: MATCH - calling onHotkeyReleased (STOP recording)", context: "HotkeyManager LOG")
                isHoldingKey = false
                onHotkeyReleased?()
            } else {
                DebugLog.info("handleKeyUpEvent: Key released but not in hold mode (continuous recording)", context: "HotkeyManager LOG")
            }
            // Always consume the event to prevent system handling
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
