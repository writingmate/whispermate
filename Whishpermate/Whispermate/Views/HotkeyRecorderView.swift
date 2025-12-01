import AppKit
import SwiftUI

// MARK: - Predefined Hotkey Options

enum HotkeyOption: String, CaseIterable, Identifiable {
    case fn = "fn"
    case rightCommand = "right_cmd"
    case rightOption = "right_opt"
    case rightShift = "right_shift"
    case rightControl = "right_ctrl"
    case optionCommand = "opt_cmd"
    case controlCommand = "ctrl_cmd"
    case controlOption = "ctrl_opt"
    case shiftCommand = "shift_cmd"
    case optionShift = "opt_shift"
    case controlShift = "ctrl_shift"
    case optionR = "opt_r"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fn: return "Fn"
        case .rightCommand: return "Right ⌘"
        case .rightOption: return "Right ⌥"
        case .rightShift: return "Right ⇧"
        case .rightControl: return "Right ⌃"
        case .optionCommand: return "⌥ + ⌘"
        case .controlCommand: return "⌃ + ⌘"
        case .controlOption: return "⌃ + ⌥"
        case .shiftCommand: return "⇧ + ⌘"
        case .optionShift: return "⌥ + ⇧"
        case .controlShift: return "⌃ + ⇧"
        case .optionR: return "⌥ + R"
        }
    }

    var hotkey: Hotkey {
        switch self {
        case .fn:
            return Hotkey(keyCode: 63, modifiers: .function)
        case .rightCommand:
            // Right Command key code is 54
            return Hotkey(keyCode: 54, modifiers: .command)
        case .rightOption:
            // Right Option key code is 61
            return Hotkey(keyCode: 61, modifiers: .option)
        case .rightShift:
            // Right Shift key code is 60
            return Hotkey(keyCode: 60, modifiers: .shift)
        case .rightControl:
            // Right Control key code is 62
            return Hotkey(keyCode: 62, modifiers: .control)
        case .optionCommand:
            // Use Space as placeholder key with modifiers
            return Hotkey(keyCode: 49, modifiers: [.option, .command])
        case .controlCommand:
            return Hotkey(keyCode: 49, modifiers: [.control, .command])
        case .controlOption:
            return Hotkey(keyCode: 49, modifiers: [.control, .option])
        case .shiftCommand:
            return Hotkey(keyCode: 49, modifiers: [.shift, .command])
        case .optionShift:
            return Hotkey(keyCode: 49, modifiers: [.option, .shift])
        case .controlShift:
            return Hotkey(keyCode: 49, modifiers: [.control, .shift])
        case .optionR:
            // R key code is 15
            return Hotkey(keyCode: 15, modifiers: .option)
        }
    }

    static func from(hotkey: Hotkey?) -> HotkeyOption? {
        guard let hotkey = hotkey else { return nil }

        // Check for Fn key
        if hotkey.modifiers == .function && hotkey.keyCode == 63 {
            return .fn
        }

        // Check for right-side modifier keys
        if hotkey.keyCode == 54 && hotkey.modifiers.contains(.command) {
            return .rightCommand
        }
        if hotkey.keyCode == 61 && hotkey.modifiers.contains(.option) {
            return .rightOption
        }
        if hotkey.keyCode == 60 && hotkey.modifiers.contains(.shift) {
            return .rightShift
        }
        if hotkey.keyCode == 62 && hotkey.modifiers.contains(.control) {
            return .rightControl
        }

        // Check for Option+R
        if hotkey.keyCode == 15 && hotkey.modifiers == .option {
            return .optionR
        }

        // Check for modifier combinations (with Space as placeholder)
        if hotkey.keyCode == 49 {
            if hotkey.modifiers == [.option, .command] {
                return .optionCommand
            }
            if hotkey.modifiers == [.control, .command] {
                return .controlCommand
            }
            if hotkey.modifiers == [.control, .option] {
                return .controlOption
            }
            if hotkey.modifiers == [.shift, .command] {
                return .shiftCommand
            }
            if hotkey.modifiers == [.option, .shift] {
                return .optionShift
            }
            if hotkey.modifiers == [.control, .shift] {
                return .controlShift
            }
        }

        return nil
    }
}

// MARK: - Hotkey Picker View

struct HotkeyRecorderView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @State private var selectedOption: HotkeyOption = .fn

    var body: some View {
        Picker("", selection: $selectedOption) {
            ForEach(HotkeyOption.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .onAppear {
            // Load current selection
            if let option = HotkeyOption.from(hotkey: hotkeyManager.currentHotkey) {
                selectedOption = option
            }
        }
        .onChange(of: selectedOption) { newValue in
            hotkeyManager.setHotkey(newValue.hotkey)
        }
    }
}
