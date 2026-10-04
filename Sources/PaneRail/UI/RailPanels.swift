import AppKit
import Combine
import PaneRailKit

/// Keeps one window controller per section the rail can show.
///
/// Controllers are made on first sight of a section and then kept: a panel that
/// has nothing to show hides itself, and keeping it alive is what lets it
/// remember where it was put.
final class RailPanels {
    private let coordinator: RailCoordinator
    private let preferences: Preferences
    private let onOpenSettings: () -> Void

    private var controllers: [String: RailWindowController] = [:]
    private var cancellable: AnyCancellable?

    /// How far below the main rail a second panel opens by default.
    private static let stackSpacing: CGFloat = 12

    init(
        coordinator: RailCoordinator,
        preferences: Preferences,
        onOpenSettings: @escaping () -> Void
    ) {
        self.coordinator = coordinator
        self.preferences = preferences
        self.onOpenSettings = onOpenSettings

        cancellable = coordinator.$sections
            .receive(on: RunLoop.main)
            .sink { [weak self] sections in self?.make(for: sections) }
    }

    private func make(for sections: [RailSection]) {
        for section in sections where controllers[section.id] == nil {
            controllers[section.id] = RailWindowController(
                coordinator: coordinator,
                preferences: preferences,
                sectionID: section.id,
                // The rail of windows takes the corner; everything else stacks
                // under it, so two panels never open on top of each other.
                stackOffset: section.id == WindowRailProvider.sectionID
                    ? 0
                    : RailGeometry.listSize(itemCount: 5, width: 0).height + Self.stackSpacing,
                onOpenSettings: onOpenSettings
            )
        }
    }
}
