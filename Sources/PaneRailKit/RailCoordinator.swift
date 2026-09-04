import Combine
import Foundation

/// Owns the rail's state: which app is in front, what rows it should show, and
/// whether the panel belongs on screen at all.
///
/// Rows come from a provider chosen per app, so an application that keeps its
/// own internal states can offer those instead of its windows. Everything is
/// injected, so the whole decision path is exercised by tests without a window
/// server or an Accessibility grant.
public final class RailCoordinator: ObservableObject {
    @Published public private(set) var app: FrontmostApp?
    @Published public private(set) var items: [RailItem] = []
    @Published public private(set) var isVisible = false
    @Published public private(set) var layout: RailLayout = .list

    public let preferences: Preferences

    private let windowProvider: RailItemProvider
    private let appSpecificProviders: [RailItemProvider]
    private let isTrusted: () -> Bool
    private let fullScreenDetector: FullScreenDetecting?
    /// The provider that produced the current rows, so a click goes back to
    /// whichever one knows how to act on them.
    private var activeProvider: RailItemProvider?
    private var cancellables = Set<AnyCancellable>()

    public init(
        windowProvider: RailItemProvider,
        appSpecificProviders: [RailItemProvider] = [],
        preferences: Preferences,
        isTrusted: @escaping () -> Bool = { true },
        fullScreenDetector: FullScreenDetecting? = nil
    ) {
        self.windowProvider = windowProvider
        self.appSpecificProviders = appSpecificProviders
        self.preferences = preferences
        self.isTrusted = isTrusted
        self.fullScreenDetector = fullScreenDetector

        // Settings changes must be reflected without waiting for the next poll.
        preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    public convenience init(
        source: WindowSource,
        preferences: Preferences,
        isTrusted: @escaping () -> Bool = { true }
    ) {
        self.init(
            windowProvider: WindowRailProvider(source: source),
            preferences: preferences,
            isTrusted: isTrusted
        )
    }

    public func setFrontmost(_ app: FrontmostApp?) {
        self.app = app
        refresh()
    }

    /// Which provider describes this app, honouring the user's preference.
    public func provider(for app: FrontmostApp) -> RailItemProvider {
        guard preferences.appSpecificProviders else { return windowProvider }
        return appSpecificProviders.first { $0.supports(app) } ?? windowProvider
    }

    public func refresh() {
        // No point paying for the lookup when the answer cannot be "show".
        guard let app, preferences.isEnabled else { return clear() }

        // Only asked when the setting is on, so the check costs nothing to
        // anyone who has turned it off.
        let isFullScreen = preferences.hidesInFullScreen
            && (fullScreenDetector?.isFullScreen(pid: app.pid) ?? false)

        // The allow list outranks everything a provider might offer, so an app
        // that is ruled out is never asked for its rows at all.
        let input = RailVisibilityInput(
            isEnabled: preferences.isEnabled,
            isAccessibilityTrusted: isTrusted(),
            bundleIdentifier: app.bundleIdentifier,
            mode: preferences.mode,
            minimumItems: preferences.minimumWindows,
            listedBundleIDs: Set(preferences.listedBundleIDs),
            isFullScreen: isFullScreen,
            hidesInFullScreen: preferences.hidesInFullScreen
        )
        guard RailVisibility.isEligible(input) else { return clear() }

        let provider = provider(for: app)
        activeProvider = provider

        let newItems = provider.items(for: app)
        if newItems != items { items = newItems }

        let newLayout = provider.layout(for: app)
        if newLayout != layout { layout = newLayout }

        let visible = RailVisibility.meetsThreshold(
            itemCount: newItems.count,
            minimumItems: preferences.minimumWindows
        )
        if visible != isVisible { isVisible = visible }
    }

    private func clear() {
        if !items.isEmpty { items = [] }
        if isVisible { isVisible = false }
        if layout != .list { layout = .list }
        activeProvider = nil
    }

    /// Acts on a row. Returns whether the provider reported success.
    @discardableResult
    public func select(_ item: RailItem) -> Bool {
        guard let app, let provider = activeProvider else { return false }
        let acted = provider.activate(item, in: app)
        refresh()
        return acted
    }
}
