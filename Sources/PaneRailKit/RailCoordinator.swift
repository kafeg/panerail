import Combine
import Foundation

/// Owns the rail's state: which app is in front, what it should show, and
/// whether the panel belongs on screen at all.
///
/// Rows arrive as sections. The window section is always asked for; an
/// application that keeps its own internal states contributes a further section
/// beside it rather than in place of it. Everything is injected, so the whole
/// decision path is exercised by tests without a window server or an
/// Accessibility grant.
public final class RailCoordinator: ObservableObject {
    @Published public private(set) var app: FrontmostApp?
    @Published public private(set) var sections: [RailSection] = []
    @Published public private(set) var isVisible = false

    public let preferences: Preferences

    private let windowProvider: RailItemProvider
    private let appSpecificProviders: [RailItemProvider]
    private let isTrusted: () -> Bool
    private let fullScreenDetector: FullScreenDetecting?
    /// Which provider owns which section, so a click goes back to whoever
    /// knows how to act on that row.
    private var providersBySection: [String: RailItemProvider] = [:]
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

    /// The providers contributing to this app, in the order their sections
    /// appear. Windows come first and always; the rest only when the user has
    /// asked for app-specific states.
    public func providers(for app: FrontmostApp) -> [RailItemProvider] {
        guard preferences.appSpecificProviders else { return [windowProvider] }
        return [windowProvider] + appSpecificProviders.filter { $0.supports(app) }
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

        var newSections: [RailSection] = []
        var owners: [String: RailItemProvider] = [:]

        for provider in providers(for: app) {
            guard let section = provider.section(for: app), !section.items.isEmpty else { continue }
            guard keeps(section) else { continue }
            newSections.append(section)
            owners[section.id] = provider
        }

        providersBySection = owners
        if newSections != sections { sections = newSections }
        if isVisible != !newSections.isEmpty { isVisible = !newSections.isEmpty }
    }

    /// The "appear from n windows" threshold is about windows, not about
    /// everything the rail can show: a browser with one window and eight
    /// workspaces still has plenty to switch between, and a lone window row
    /// beside them would be noise.
    private func keeps(_ section: RailSection) -> Bool {
        guard section.id == WindowRailProvider.sectionID else { return true }
        return RailVisibility.meetsThreshold(
            itemCount: section.items.count,
            minimumItems: preferences.minimumWindows
        )
    }

    private func clear() {
        if !sections.isEmpty { sections = [] }
        if isVisible { isVisible = false }
        providersBySection = [:]
    }

    /// Acts on a row, through whichever provider owns the section it came from.
    @discardableResult
    public func select(_ item: RailItem) -> Bool {
        guard let app, let provider = providersBySection[item.id.section] else { return false }
        let acted = provider.activate(item, in: app)
        refresh()
        return acted
    }

    /// Every row across every section, for callers that only need a count.
    public var items: [RailItem] { sections.flatMap(\.items) }
}
