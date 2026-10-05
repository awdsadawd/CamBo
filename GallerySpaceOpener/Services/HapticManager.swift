import UIKit

/// Manages tactile haptic feedback across GallerySpaceOpener.
public final class HapticManager {
    public static let shared = HapticManager()

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        selectionFeedback.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
    }

    public func selection() {
        selectionFeedback.selectionChanged()
    }

    public func swipeKeep() {
        lightImpact.impactOccurred()
    }

    public func swipeDelete() {
        mediumImpact.impactOccurred()
    }

    public func undo() {
        lightImpact.impactOccurred(intensity: 0.8)
    }

    public func deletionSuccess() {
        notificationFeedback.notificationOccurred(.success)
    }

    public func error() {
        notificationFeedback.notificationOccurred(.error)
    }
}
