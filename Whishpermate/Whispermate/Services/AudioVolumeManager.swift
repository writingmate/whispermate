import Foundation
import CoreAudio
import AudioToolbox

class AudioVolumeManager {
    private var originalVolume: Float?
    private var targetVolumeLevel: Float = 0.3  // Set volume to 30% (0.0 to 1.0 scale)

    /// Lowers the system volume to a specific level and stores the original volume for restoration
    func lowerVolume() {
        guard let currentVolume = getSystemVolume() else {
            DebugLog.info("Failed to get current volume", context: "AudioVolumeManager")
            return
        }

        // Store the current volume so we can restore it later
        originalVolume = currentVolume

        DebugLog.info("Lowering volume from \(currentVolume) to \(targetVolumeLevel)", context: "AudioVolumeManager")
        setSystemVolume(targetVolumeLevel)
    }

    /// Restores the volume to the original level before it was lowered
    func restoreVolume() {
        guard let volume = originalVolume else {
            DebugLog.info("No original volume to restore", context: "AudioVolumeManager")
            return
        }

        DebugLog.info("Restoring volume to \(volume)", context: "AudioVolumeManager")
        setSystemVolume(volume)
        originalVolume = nil
    }

    // MARK: - Private Helpers

    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else {
            DebugLog.info("Error getting default output device: \(status)", context: "AudioVolumeManager")
            return nil
        }

        return deviceID
    }

    private func getSystemVolume() -> Float? {
        guard let deviceID = getDefaultOutputDevice() else {
            return nil
        }

        var volume: Float = 0.0
        var propertySize = UInt32(MemoryLayout<Float>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )

        guard status == noErr else {
            DebugLog.info("Error getting volume: \(status)", context: "AudioVolumeManager")
            return nil
        }

        return volume
    }

    private func setSystemVolume(_ volume: Float) {
        guard let deviceID = getDefaultOutputDevice() else {
            return
        }

        var newVolume = max(0.0, min(1.0, volume)) // Clamp between 0 and 1
        let propertySize = UInt32(MemoryLayout<Float>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            propertySize,
            &newVolume
        )

        if status != noErr {
            DebugLog.info("Error setting volume: \(status)", context: "AudioVolumeManager")
        }
    }
}
