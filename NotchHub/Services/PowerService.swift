import Foundation
import IOKit.pwr_mgt
import Observation

/// Keep-awake: holds an IOPMAssertion that prevents display sleep while on.
@Observable
@MainActor
final class PowerService {
    private(set) var isKeepingAwake = false

    /// Called after every change (drives the idle-notch indicator dot).
    @ObservationIgnored var onChange: ((Bool) -> Void)?
    @ObservationIgnored private var assertionID: IOPMAssertionID = 0

    func toggle() {
        setKeepAwake(!isKeepingAwake)
    }

    func setKeepAwake(_ enabled: Bool) {
        guard enabled != isKeepingAwake else { return }

        if enabled {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NotchHub Keep Awake" as CFString,
                &id
            )
            guard result == kIOReturnSuccess else {
                NSLog("NotchHub: couldn't create keep-awake assertion (\(result))")
                return
            }
            assertionID = id
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        isKeepingAwake = enabled
        onChange?(enabled)
    }
}
