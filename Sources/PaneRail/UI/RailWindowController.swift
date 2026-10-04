import AppKit
import Combine
import PaneRailKit
import SwiftUI

/// One floating panel, showing one section.
///
/// Sections get a panel each rather than sharing one: the rail of windows is
/// the same object in every application, and an app's own states are a separate
/// thing to place, size and remember. Each panel keeps its own position.
final class RailWindowController {
    private let panel = RailPanel()
    private let coordinator: RailCoordinator
    private let preferences: Preferences
    private let sectionID: String
    /// How far below the default placement this panel opens, so a second panel
    /// does not land on top of the first.
    private let stackOffset: CGFloat
    private let onOpenSettings: () -> Void

    private var hostingView: FirstMouseHostingView<RailView>?
    private var cancellables = Set<AnyCancellable>()
    private var moveObserver: NSObjectProtocol?
    private var savePositionWork: DispatchWorkItem?
    private var isShown = false
    /// Frame changes we make ourselves also fire `didMove`; without this flag
    /// the default placement would immediately be persisted as a user choice.
    private var isAdjustingFrame = false

    private static let fadeDuration: TimeInterval = 0.12
    private static let positionSaveDelay: TimeInterval = 0.4

    init(
        coordinator: RailCoordinator,
        preferences: Preferences,
        sectionID: String,
        stackOffset: CGFloat = 0,
        onOpenSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.preferences = preferences
        self.sectionID = sectionID
        self.stackOffset = stackOffset
        self.onOpenSettings = onOpenSettings

        // Several things move or resize a panel, and by the time these are
        // delivered on the run loop the properties behind them have settled —
        // so the handler reads current state instead of juggling combinators.
        let triggers: [AnyPublisher<Void, Never>] = [
            coordinator.$sections.map { _ in () }.eraseToAnyPublisher(),
            coordinator.$isVisible.map { _ in () }.eraseToAnyPublisher(),
            // The front app matters: in per-application mode each one has its
            // own remembered position.
            coordinator.$app.map { _ in () }.eraseToAnyPublisher(),
            preferences.widthPublisher.map { _ in () }.eraseToAnyPublisher(),
            preferences.positionPublisher.map { _ in () }.eraseToAnyPublisher(),
        ]

        Publishers.MergeMany(triggers)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.apply() }
            .store(in: &cancellables)

        // `queue: nil` keeps delivery synchronous. With a queue the block would
        // run after `apply` has already cleared `isAdjustingFrame`, and the
        // default placement would be persisted as if the user had chosen it.
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: nil
        ) { [weak self] _ in
            self?.schedulePositionSave()
        }
    }

    deinit {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
    }

    private var section: RailSection? {
        coordinator.sections.first { $0.id == sectionID }
    }

    private func apply() {
        guard coordinator.isVisible, let section else {
            setVisible(false)
            return
        }

        let rail = RailView(
            coordinator: coordinator,
            preferences: preferences,
            section: section,
            onOpenSettings: onOpenSettings,
            onSelect: { [weak coordinator] item in coordinator?.select(item) }
        )

        // The section is a value, so the hosted view has to be handed the new
        // one rather than left to notice.
        if let hostingView {
            hostingView.rootView = rail
        } else {
            let view = FirstMouseHostingView(rootView: rail)
            panel.contentView = view
            hostingView = view
        }

        let size = RailGeometry.size(for: section, width: CGFloat(preferences.width))
        isAdjustingFrame = true
        panel.setFrame(targetFrame(for: size), display: true)
        isAdjustingFrame = false

        setVisible(true)
    }

    private func setVisible(_ visible: Bool) {
        guard visible != isShown else { return }
        isShown = visible

        if visible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fadeDuration
                panel.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Self.fadeDuration
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                // A show may have raced in while the fade ran.
                guard let self, !self.isShown else { return }
                self.panel.orderOut(nil)
            })
        }
    }

    /// The saved anchor is the panel's top-left corner, so it grows downwards
    /// as rows appear instead of drifting off the top of the screen.
    private func targetFrame(for size: CGSize) -> CGRect {
        let anchor = preferences.origin(for: coordinator.app?.bundleIdentifier, section: sectionID)
        let screen = anchor.flatMap { point in
            NSScreen.screens.first { $0.frame.contains(point) }
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let visibleFrame = screen?.visibleFrame else {
            return CGRect(origin: .zero, size: size)
        }

        let proposed: CGPoint
        if let anchor {
            proposed = CGPoint(x: anchor.x, y: anchor.y - size.height)
        } else {
            proposed = RailGeometry.defaultOrigin(
                size: size,
                in: visibleFrame,
                stackedBelow: stackOffset
            )
        }

        return CGRect(
            origin: RailGeometry.clamp(origin: proposed, size: size, into: visibleFrame),
            size: size
        )
    }

    private func schedulePositionSave() {
        guard !isAdjustingFrame else { return }
        savePositionWork?.cancel()

        let frame = panel.frame
        let bundleID = coordinator.app?.bundleIdentifier
        let section = sectionID
        let work = DispatchWorkItem { [weak self] in
            self?.preferences.setOrigin(
                CGPoint(x: frame.minX, y: frame.maxY),
                for: bundleID,
                section: section
            )
        }
        savePositionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.positionSaveDelay, execute: work)
    }
}
