//
//  AudioDeviceManager.swift
//  Whispermate
//
//  Manages audio input device selection on macOS using Core Audio
//

import Foundation
import CoreAudio
import AVFoundation

class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    struct AudioDevice: Identifiable, Equatable, Hashable {
        let id: AudioDeviceID
        let name: String
        let uniqueID: String

        var localizedName: String { name }

        static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
            return lhs.uniqueID == rhs.uniqueID
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(uniqueID)
        }
    }

    private init() {
        setupDeviceChangeListener()
    }

    // MARK: - Device Enumeration

    func getInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []

        // Get list of all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return devices }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        let getDevicesStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard getDevicesStatus == noErr else { return devices }

        // Filter for input devices only
        for deviceID in audioDevices {
            if hasInputStreams(deviceID: deviceID),
               let name = getDeviceName(deviceID: deviceID),
               let uid = getDeviceUID(deviceID: deviceID) {
                devices.append(AudioDevice(id: deviceID, name: name, uniqueID: uid))
            }
        }

        return devices
    }

    func getDefaultInputDevice() -> AudioDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == noErr,
              let name = getDeviceName(deviceID: deviceID),
              let uid = getDeviceUID(deviceID: deviceID) else {
            return nil
        }

        return AudioDevice(id: deviceID, name: name, uniqueID: uid)
    }

    func setDefaultInputDevice(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceIDCopy = deviceID
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &deviceIDCopy
        )

        if status == noErr {
            DebugLog.info("Successfully set default input device to ID: \(deviceID)", context: "AudioDeviceManager")
            return true
        } else {
            DebugLog.info("Failed to set default input device, status: \(status)", context: "AudioDeviceManager")
            return false
        }
    }

    // MARK: - Helper Functions

    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return false }

        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }

        let getDataStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferList
        )

        guard getDataStatus == noErr else { return false }

        return bufferList.pointee.mNumberBuffers > 0
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return nil }

        var name: CFString = "" as CFString
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &name
        )

        guard status == noErr else { return nil }
        return name as String
    }

    private func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return nil }

        var uid: CFString = "" as CFString
        status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &uid
        )

        guard status == noErr else { return nil }
        return uid as String
    }

    // MARK: - Device Change Listener

    private func setupDeviceChangeListener() {
        // Listen for device list changes
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            deviceListChangedCallback,
            nil
        )

        // Listen for default device changes
        propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice

        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            deviceListChangedCallback,
            nil
        )
    }
}

// Callback for device changes
private func deviceListChangedCallback(
    _ inObjectID: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioDeviceListChanged"),
            object: nil
        )
    }
    return noErr
}
