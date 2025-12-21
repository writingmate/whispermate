//
//  WhisperMateShared.swift
//  WhisperMateShared
//
//  Created by Artsiom Vysotski on 11/4/25.
//

import Foundation

// MARK: - Build Configuration Aware UserDefaults

/// Provides separate UserDefaults storage for Debug and Release builds
/// This prevents settings conflicts when switching between build configurations
public enum AppDefaults {
    /// The shared UserDefaults instance for the current build configuration
    /// - Debug: Uses "com.whispermate.macos.debug" suite (separate storage)
    /// - Release: Uses UserDefaults.standard (bundle ID: com.whispermate.macos)
    public static var shared: UserDefaults {
        #if DEBUG
        return UserDefaults(suiteName: "com.whispermate.macos.debug") ?? .standard
        #else
        return .standard
        #endif
    }

    /// Whether the app is running in Debug mode
    public static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
