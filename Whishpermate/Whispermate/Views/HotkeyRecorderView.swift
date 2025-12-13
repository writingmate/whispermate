import AppKit
import SwiftUI

// MARK: - Hotkey Type

enum HotkeyType {
    case dictation
    case command
}

// MARK: - Predefined Hotkey Options

enum HotkeyOption: String, CaseIterable, Identifiable {
    case fn = "fn"
    case leftControl = "left_ctrl"
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
    // Mouse buttons
    case mouseMiddle = "mouse_middle"
    case mouseSide1 = "mouse_side1"
    case mouseSide2 = "mouse_side2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fn: return "Fn"
        case .leftControl: return "Left ⌃"
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
        case .mouseMiddle: return "Middle Click"
        case .mouseSide1: return "Side Button 1"
        case .mouseSide2: return "Side Button 2"
        }
    }

    var hotkey: Hotkey {
        switch self {
        case .fn:
            return Hotkey(keyCode: 63, modifiers: .function)
        case .leftControl:
            // Left Control key code is 59
            return Hotkey(keyCode: 59, modifiers: .control)
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
        case .mouseMiddle:
            // Middle click is button 2
            return Hotkey(keyCode: 0, modifiers: [], mouseButton: 2)
        case .mouseSide1:
            // Side button 1 (back) is button 3
            return Hotkey(keyCode: 0, modifiers: [], mouseButton: 3)
        case .mouseSide2:
            // Side button 2 (forward) is button 4
            return Hotkey(keyCode: 0, modifiers: [], mouseButton: 4)
        }
    }

    static func from(hotkey: Hotkey?) -> HotkeyOption? {
        guard let hotkey = hotkey else { return nil }

        // Check for mouse buttons first
        if let mouseButton = hotkey.mouseButton {
            switch mouseButton {
            case 2: return .mouseMiddle
            case 3: return .mouseSide1
            case 4: return .mouseSide2
            default: return nil
            }
        }

        // Check for Fn key
        if hotkey.modifiers == .function && hotkey.keyCode == 63 {
            return .fn
        }

        // Check for left Control (keyCode 59)
        if hotkey.keyCode == 59 && hotkey.modifiers.contains(.control) {
            return .leftControl
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
    var hotkeyType: HotkeyType = .dictation
    @State private var selectedOption: HotkeyOption = .fn

    private var currentHotkey: Hotkey? {
        switch hotkeyType {
        case .dictation: return hotkeyManager.currentHotkey
        case .command: return hotkeyManager.commandHotkey
        }
    }

    private var defaultOption: HotkeyOption {
        switch hotkeyType {
        case .dictation: return .fn
        case .command: return .leftControl
        }
    }

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
            if let option = HotkeyOption.from(hotkey: currentHotkey) {
                selectedOption = option
            } else {
                selectedOption = defaultOption
            }
        }
        .onChange(of: selectedOption) { newValue in
            switch hotkeyType {
            case .dictation:
                hotkeyManager.setHotkey(newValue.hotkey)
            case .command:
                hotkeyManager.setCommandHotkey(newValue.hotkey)
            }
        }
    }
}
