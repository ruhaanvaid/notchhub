import CoreAudio
import Foundation

/// Small typed wrappers over the CoreAudio property API.
enum AudioHAL {
    static let systemObject = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func has(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(object, &address)
    }

    static func isSettable(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(object, &address, &settable) == noErr && settable.boolValue
    }

    /// For plain scalar property values (IDs, flags, Float32 volumes).
    static func get<T: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, initial: T) -> T? {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
        }
        return status == noErr ? value : nil
    }

    @discardableResult
    static func set<T: BitwiseCopyable>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: T) -> Bool {
        var address = address
        let status = withUnsafeBytes(of: value) { buffer in
            AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(buffer.count), buffer.baseAddress!)
        }
        return status == noErr
    }

    static func getArray<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, of _: T.Type) -> [T] {
        var address = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        return [T](unsafeUninitializedCapacity: count) { buffer, initialized in
            var size = size
            let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
            initialized = status == noErr ? Int(size) / MemoryLayout<T>.stride : 0
        }
    }

    static func string(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value)
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static var defaultOutputDevice: AudioDeviceID? {
        let id = get(systemObject, address(kAudioHardwarePropertyDefaultOutputDevice), initial: AudioDeviceID(kAudioObjectUnknown))
        guard let id, id != kAudioObjectUnknown else { return nil }
        return id
    }
}

/// A registered CoreAudio property listener that can be removed later.
@MainActor
final class CoreAudioListener {
    private let object: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let block: AudioObjectPropertyListenerBlock
    private var isActive = false

    /// `handler` runs on the main queue.
    init(object: AudioObjectID, address: AudioObjectPropertyAddress, handler: @escaping @MainActor () -> Void) {
        self.object = object
        self.address = address
        self.block = { _, _ in
            MainActor.assumeIsolated { handler() }
        }
        isActive = AudioObjectAddPropertyListenerBlock(object, &self.address, .main, block) == noErr
    }

    func remove() {
        guard isActive else { return }
        AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        isActive = false
    }
}
