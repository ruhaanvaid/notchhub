import CoreGraphics
import Foundation

/// Abstraction over whatever can read and set a display's brightness. The only implementation
/// uses a private framework, so it's isolated here and every caller copes with it being absent.
protocol BrightnessProvider {
    func canChangeBrightness(of display: CGDirectDisplayID) -> Bool
    func brightness(of display: CGDirectDisplayID) -> Float?
    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool
}

/// Private DisplayServices framework, loaded at runtime with dlopen. `init` fails if the
/// framework or its symbols are missing, and the brightness keys are then passed through.
final class DisplayServicesBrightnessProvider: BrightnessProvider {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeBrightness = @convention(c) (CGDirectDisplayID) -> Bool

    private static let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    private let handle: UnsafeMutableRawPointer
    private let getBrightness: GetBrightness
    private let setBrightnessFn: SetBrightness
    private let canChange: CanChangeBrightness?

    init?() {
        guard let handle = dlopen(Self.path, RTLD_LAZY) else { return nil }
        guard let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            dlclose(handle)
            return nil
        }
        self.handle = handle
        self.getBrightness = unsafeBitCast(get, to: GetBrightness.self)
        self.setBrightnessFn = unsafeBitCast(set, to: SetBrightness.self)
        self.canChange = dlsym(handle, "DisplayServicesCanChangeBrightness")
            .map { unsafeBitCast($0, to: CanChangeBrightness.self) }
    }

    deinit {
        dlclose(handle)
    }

    func canChangeBrightness(of display: CGDirectDisplayID) -> Bool {
        if let canChange { return canChange(display) }
        return brightness(of: display) != nil
    }

    func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        setBrightnessFn(display, value) == 0
    }
}

/// Built-in display brightness.
@MainActor
final class BrightnessService {
    static let coarseSteps: Float = 16
    static let fineSteps: Float = 64

    private let provider: BrightnessProvider?

    init(provider: BrightnessProvider? = DisplayServicesBrightnessProvider()) {
        self.provider = provider
    }

    /// The built-in display, if it's online (it isn't with the lid closed).
    var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// False when the private framework is unavailable or there's no built-in display.
    var canAdjust: Bool {
        guard let provider, let display = builtInDisplay else { return false }
        return provider.canChangeBrightness(of: display) && provider.brightness(of: display) != nil
    }

    var brightness: Float? {
        guard let provider, let display = builtInDisplay else { return nil }
        return provider.brightness(of: display)
    }

    /// Returns the new level, or nil if it couldn't be changed.
    func step(up: Bool, fine: Bool) -> Double? {
        guard let provider, let display = builtInDisplay,
              let current = provider.brightness(of: display)
        else { return nil }

        let steps = fine ? Self.fineSteps : Self.coarseSteps
        let index = (current * steps).rounded() + (up ? 1 : -1)
        let newValue = min(max(index / steps, 0), 1)
        guard provider.setBrightness(newValue, of: display) else { return nil }
        return Double(newValue)
    }
}
