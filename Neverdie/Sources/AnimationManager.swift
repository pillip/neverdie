import AppKit
import os

/// Transition animation type for state changes.
enum AnimationTransition: Equatable, Sendable {
    /// OFF -> ON: zombie wakes up
    case wakeUp
    /// ON -> OFF (manual): zombie falls asleep
    case fallAsleep
    /// ON -> OFF (auto): all sessions ended, longer transition
    case autoOff
}

/// Manages frame-based animation for the menu bar icon.
///
/// AnimationManager pre-loads all animation frames from the asset catalog at init,
/// cycles through them at 6fps via Timer, and provides a `currentFrame` property
/// for the StatusBarController to observe.
///
/// Supports:
/// - Main loop animation (ON state)
/// - Transition animations (wake-up, fall-asleep, auto-OFF)
/// - Reduced motion accessibility (static frame instead of animation)
/// - Fallback to SF Symbol if assets are missing
final class AnimationManager {
    private let logger = Logger.ui

    // MARK: - Frame Data

    /// Main loop frames (ZombieOn_01 through ZombieOn_04).
    private let loopFrames: [NSImage]

    /// Wake-up transition frames (ZombieWake_01, ZombieWake_02).
    private let wakeUpFrames: [NSImage]

    /// Fall-asleep transition frames (ZombieSleepTrans_01 through ZombieSleepTrans_03).
    private let fallAsleepFrames: [NSImage]

    /// Auto-OFF transition frames (ZombieAutoOff_01 through ZombieAutoOff_04).
    private let autoOffFrames: [NSImage]

    /// Static OFF icon (sleeping zombie).
    let staticOffIcon: NSImage

    /// Fallback icon when assets are missing.
    private let fallbackIcon: NSImage

    // MARK: - Animation State

    /// The current frame to display in the menu bar.
    private(set) var currentFrame: NSImage

    /// Timer for frame cycling.
    private var timer: Timer?

    /// Current index in the active frame sequence.
    private var frameIndex: Int = 0

    /// Whether a transition is currently playing.
    private var isPlayingTransition: Bool = false

    /// Frames currently being played (transition or loop).
    private var activeFrames: [NSImage] = []

    /// Completion handler for the current transition.
    private var transitionCompletion: (() -> Void)?

    /// Frames per second for animation.
    let fps: Double = 6.0

    /// Whether the main loop animation is running.
    private(set) var isAnimating: Bool = false

    // MARK: - Accessibility

    /// Whether reduced motion is enabled.
    var reducedMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Observer token for accessibility changes.
    private var accessibilityObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        // Load fallback icon
        fallbackIcon = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Neverdie active")
            ?? NSImage()
        fallbackIcon.isTemplate = true
        fallbackIcon.size = NSSize(width: 18, height: 18)

        // Load static OFF icon
        if let offImg = NSImage(named: "ZombieSleep") {
            offImg.isTemplate = true
            offImg.size = NSSize(width: 18, height: 18)
            staticOffIcon = offImg
        } else {
            staticOffIcon = fallbackIcon
        }

        // Pre-load animation frames
        loopFrames = AnimationManager.loadFrames(
            names: ["ZombieOn_01", "ZombieOn_02", "ZombieOn_03", "ZombieOn_04"],
            fallback: fallbackIcon
        )
        wakeUpFrames = AnimationManager.loadFrames(
            names: ["ZombieWake_01", "ZombieWake_02"],
            fallback: fallbackIcon
        )
        fallAsleepFrames = AnimationManager.loadFrames(
            names: ["ZombieSleepTrans_01", "ZombieSleepTrans_02", "ZombieSleepTrans_03"],
            fallback: fallbackIcon
        )
        autoOffFrames = AnimationManager.loadFrames(
            names: ["ZombieAutoOff_01", "ZombieAutoOff_02", "ZombieAutoOff_03", "ZombieAutoOff_04"],
            fallback: fallbackIcon
        )

        // Start with static OFF icon
        currentFrame = staticOffIcon

        // Observe accessibility changes
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAccessibilityChange()
        }

        logger.info("AnimationManager initialized: \(self.loopFrames.count) loop, \(self.wakeUpFrames.count) wake, \(self.fallAsleepFrames.count) sleep, \(self.autoOffFrames.count) autoOff frames")
    }

    deinit {
        stopAnimation()
        if let observer = accessibilityObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Frame Loading

    /// Load frames from the asset catalog with fallback support.
    private static func loadFrames(names: [String], fallback: NSImage) -> [NSImage] {
        var frames: [NSImage] = []
        for name in names {
            if let img = NSImage(named: name) {
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                frames.append(img)
            } else {
                Logger.ui.warning("Animation frame '\(name)' not found, using fallback")
                frames.append(fallback)
            }
        }
        return frames
    }

    // MARK: - Animation Control

    /// Start the main loop animation.
    ///
    /// If reduced motion is enabled, sets a single static ON frame instead.
    func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        if reducedMotionEnabled {
            // Static ON frame for reduced motion
            currentFrame = loopFrames.first ?? fallbackIcon
            logger.info("Animation started (reduced motion: static frame)")
            return
        }

        activeFrames = loopFrames
        frameIndex = 0
        currentFrame = activeFrames[0]
        startTimer()
        logger.info("Animation started at \(self.fps)fps")
    }

    /// Stop the animation and return to the static OFF icon.
    func stopAnimation() {
        isAnimating = false
        isPlayingTransition = false
        transitionCompletion = nil
        stopTimer()
        currentFrame = staticOffIcon
        frameIndex = 0
        activeFrames = []
        logger.info("Animation stopped")
    }

    /// Play a transition animation, then optionally enter the main loop.
    ///
    /// - Parameters:
    ///   - type: The transition type to play.
    ///   - completion: Called when the transition finishes.
    func playTransition(type: AnimationTransition, completion: (() -> Void)? = nil) {
        // Stop any current animation
        stopTimer()
        isPlayingTransition = true
        transitionCompletion = completion

        if reducedMotionEnabled {
            // Skip transition in reduced motion mode
            isPlayingTransition = false
            completion?()
            return
        }

        let frames: [NSImage]
        switch type {
        case .wakeUp:
            frames = wakeUpFrames
        case .fallAsleep:
            frames = fallAsleepFrames
        case .autoOff:
            frames = autoOffFrames
        }

        activeFrames = frames
        frameIndex = 0

        if frames.isEmpty {
            isPlayingTransition = false
            completion?()
            return
        }

        currentFrame = frames[0]
        startTimer()
        logger.info("Playing transition: \(String(describing: type)) (\(frames.count) frames)")
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let interval = 1.0 / fps
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
        timer?.tolerance = 0.05 // 50ms tolerance
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Advance to the next frame.
    private func advanceFrame() {
        guard !activeFrames.isEmpty else { return }

        frameIndex += 1

        if isPlayingTransition {
            // During transition: play through once then call completion
            if frameIndex >= activeFrames.count {
                isPlayingTransition = false
                let completion = transitionCompletion
                transitionCompletion = nil

                // If still animating, enter the main loop
                if isAnimating {
                    activeFrames = loopFrames
                    frameIndex = 0
                    if !activeFrames.isEmpty {
                        currentFrame = activeFrames[0]
                    }
                } else {
                    stopTimer()
                }

                completion?()
                return
            }
        } else {
            // Loop: wrap around
            frameIndex = frameIndex % activeFrames.count
        }

        currentFrame = activeFrames[frameIndex]
    }

    // MARK: - Accessibility

    private func handleAccessibilityChange() {
        if reducedMotionEnabled && isAnimating {
            stopTimer()
            currentFrame = loopFrames.first ?? fallbackIcon
            logger.info("Reduced motion enabled, switching to static frame")
        } else if !reducedMotionEnabled && isAnimating && timer == nil {
            // Re-enable animation
            activeFrames = loopFrames
            frameIndex = 0
            currentFrame = activeFrames[0]
            startTimer()
            logger.info("Reduced motion disabled, resuming animation")
        }
    }
}
