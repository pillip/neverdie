import Foundation
import IOKit.ps
import os

/// Observes AC vs battery power transitions via IOKit power source notifications.
///
/// Uses `IOPSNotificationCreateRunLoopSource` for callback-driven updates
/// rather than polling. The initial power source is read synchronously on `start()`.
final class PowerSourceMonitor: PowerSourceMonitoring {
    private(set) var currentSource: PowerSource = .ac

    private var runLoopSource: CFRunLoopSource?
    private var onChange: ((PowerSource) -> Void)?
    private let logger = Logger.sleep

    func start(onChange: @escaping (PowerSource) -> Void) {
        self.onChange = onChange

        // Read initial state synchronously
        currentSource = readPowerSource()
        logger.info("PowerSourceMonitor: initial power source = \(String(describing: self.currentSource))")

        // Register for notifications
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource(
            powerSourceCallback,
            selfPtr
        )

        if let source = source {
            runLoopSource = source.takeRetainedValue()
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        } else {
            logger.error("PowerSourceMonitor: failed to create run loop source")
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
        onChange = nil
        logger.info("PowerSourceMonitor stopped")
    }

    deinit {
        stop()
    }

    // MARK: - Internal

    fileprivate func handlePowerSourceChange() {
        let newSource = readPowerSource()
        guard newSource != currentSource else { return }
        currentSource = newSource
        logger.info("PowerSourceMonitor: power source changed to \(String(describing: self.currentSource))")
        onChange?(currentSource)
    }

    private func readPowerSource() -> PowerSource {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              !list.isEmpty else {
            // No power sources (desktop Mac) — default to AC
            return .ac
        }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let powerSourceState = desc[kIOPSPowerSourceStateKey] as? String else {
                continue
            }
            if powerSourceState == kIOPSACPowerValue {
                return .ac
            } else if powerSourceState == kIOPSBatteryPowerValue {
                return .battery
            }
        }

        return .ac
    }
}

/// C callback for IOKit power source notification.
private func powerSourceCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(context).takeUnretainedValue()
    if Thread.isMainThread {
        monitor.handlePowerSourceChange()
    } else {
        DispatchQueue.main.async {
            monitor.handlePowerSourceChange()
        }
    }
}
