import Foundation
import IOKit
import os

/// Observes MacBook lid open/close state via IOKit root domain interest notifications.
///
/// Uses `IOServiceAddInterestNotification` on `IOPMrootDomain` to receive
/// callbacks whenever the `AppleClamshellState` property changes.
/// The notification port's run loop source is added to the main run loop
/// so callbacks fire on the main thread.
final class ClamshellObserver: ClamshellObserving {
    private(set) var isLidClosed: Bool = false

    private var notificationPort: IONotificationPortRef?
    private var notifyIterator: io_object_t = IO_OBJECT_NULL
    private var onChange: ((Bool) -> Void)?
    private var rootDomainService: io_service_t = IO_OBJECT_NULL
    private let logger = Logger.sleep

    func start(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange

        rootDomainService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard rootDomainService != IO_OBJECT_NULL else {
            logger.error("ClamshellObserver: failed to find IOPMrootDomain service")
            return
        }

        // Read initial state
        isLidClosed = readClamshellState(from: rootDomainService)
        logger.info("ClamshellObserver: initial lid state = \(self.isLidClosed ? "closed" : "open")")

        // Register for interest notifications
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let port = notificationPort else {
            logger.error("ClamshellObserver: failed to create notification port")
            IOObjectRelease(rootDomainService)
            rootDomainService = IO_OBJECT_NULL
            return
        }

        let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let result = IOServiceAddInterestNotification(
            port,
            rootDomainService,
            kIOGeneralInterest,
            clamshellCallback,
            selfPtr,
            &notifyIterator
        )

        if result != kIOReturnSuccess {
            logger.error("ClamshellObserver: IOServiceAddInterestNotification failed (\(result))")
            stop()
        }
    }

    func stop() {
        if notifyIterator != IO_OBJECT_NULL {
            IOObjectRelease(notifyIterator)
            notifyIterator = IO_OBJECT_NULL
        }
        if let port = notificationPort {
            let runLoopSource = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
            IONotificationPortDestroy(port)
            notificationPort = nil
        }
        if rootDomainService != IO_OBJECT_NULL {
            IOObjectRelease(rootDomainService)
            rootDomainService = IO_OBJECT_NULL
        }
        onChange = nil
        logger.info("ClamshellObserver stopped")
    }

    deinit {
        stop()
    }

    // MARK: - Internal

    fileprivate func handleNotification() {
        guard rootDomainService != IO_OBJECT_NULL else { return }
        let newState = readClamshellState(from: rootDomainService)
        guard newState != isLidClosed else { return }
        isLidClosed = newState
        logger.info("ClamshellObserver: lid state changed to \(self.isLidClosed ? "closed" : "open")")
        onChange?(isLidClosed)
    }

    private func readClamshellState(from service: io_service_t) -> Bool {
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        ) else {
            // nil during transitions — treat as unchanged
            return isLidClosed
        }
        return (prop.takeRetainedValue() as? Bool) ?? false
    }
}

/// C callback trampoline for IOKit interest notification.
private func clamshellCallback(
    _ refcon: UnsafeMutableRawPointer?,
    _ service: io_service_t,
    _ messageType: UInt32,
    _ messageArgument: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let observer = Unmanaged<ClamshellObserver>.fromOpaque(refcon).takeUnretainedValue()
    // Marshal to main thread for thread safety
    if Thread.isMainThread {
        observer.handleNotification()
    } else {
        DispatchQueue.main.async {
            observer.handleNotification()
        }
    }
}
