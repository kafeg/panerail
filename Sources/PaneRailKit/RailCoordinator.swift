import Combine
import Foundation

/// Owns the rail's state: which app is in front, its windows, and whether the
/// panel should be on screen at all.
///
/// Everything it needs is injected, so the whole decision path can be driven
/// from tests without a window server or an Accessibility grant.
public final class RailCoordinator: ObservableObject {
    @Published public private(set) var app: FrontmostApp?
    @Published public private(set) var windows: [WindowInfo] = []
    @Published public private(set) var isVisible = false

    public let preferences: Preferences

    private let source: WindowSource
    private let isTrusted: () -> Bool
    private var cancellables = Set<AnyCancellable>()

    public init(
        source: WindowSource,
        preferences: Preferences,
        isTrusted: @escaping () -> Bool = { true }
    ) {
        self.source = source
        self.preferences = preferences
        self.isTrusted = isTrusted

        // Settings changes must be reflected without waiting for the next poll.
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    public func setFrontmost(_ app: FrontmostApp?) {
        self.app = app
        refresh()
    }

    /// Re-reads the current app's windows and recomputes visibility.
    public func refresh() {
        // No point paying for an AX round trip when the answer cannot be "show".
        guard let app, preferences.isEnabled else {
            if !windows.isEmpty { windows = [] }
            if isVisible { isVisible = false }
            return
        }

        let raw = isTrusted() ? source.windows(for: app.pid) : []
        let normalized = WindowList.normalize(raw, appName: app.name)
        if normalized != windows { windows = normalized }

        let visible = RailVisibility.shouldShow(
            RailVisibilityInput(
                isEnabled: preferences.isEnabled,
                isAccessibilityTrusted: isTrusted(),
                bundleIdentifier: app.bundleIdentifier,
                windowCount: normalized.count,
                mode: preferences.mode,
                minimumWindows: preferences.minimumWindows,
                listedBundleIDs: Set(preferences.listedBundleIDs)
            )
        )
        if visible != isVisible { isVisible = visible }
    }

    /// Brings the given window to the front. Returns whether the AX call landed.
    @discardableResult
    public func select(_ window: WindowInfo) -> Bool {
        guard let app else { return false }
        let raised = source.raise(window, pid: app.pid)
        refresh()
        return raised
    }
}
