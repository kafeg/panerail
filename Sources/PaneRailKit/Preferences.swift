import Combine
import CoreGraphics
import Foundation

/// Whether the rail keeps one position or one per application.
public enum RailPositionMode: String, CaseIterable, Identifiable, Codable {
    /// One position, wherever the rail was last dropped.
    case shared
    /// Each application remembers where its rail was left. An application that
    /// has not been placed yet opens at the default position rather than
    /// borrowing another application's.
    case perApp

    public var id: String { rawValue }
}

/// Which apps the rail is allowed to appear for.
public enum RailMode: String, CaseIterable, Identifiable, Codable {
    /// Any app that satisfies the window-count threshold.
    case allApps
    /// Only apps the user explicitly added.
    case listedApps
    /// Every app except the ones the user added.
    case exceptListedApps

    public var id: String { rawValue }
}

/// User-facing settings, persisted in `UserDefaults`.
///
/// The store is injectable so tests can run against a throwaway suite instead
/// of polluting the real domain.
public final class Preferences: ObservableObject {
    enum Key {
        static let isEnabled = "rail.isEnabled"
        static let mode = "rail.mode"
        static let minimumWindows = "rail.minimumWindows"
        static let listedBundleIDs = "rail.listedBundleIDs"
        static let appSpecificProviders = "rail.appSpecificProviders"
        static let hidesInFullScreen = "rail.hidesInFullScreen"
        static let positionMode = "rail.positionMode"
        static let originsByApp = "rail.originsByApp"
        static let sharedOrigins = "rail.sharedOrigins"
        static let vivaldiIconStrip = "rail.vivaldi.iconStrip"
        static let width = "rail.width"
        static let originX = "rail.originX"
        static let originY = "rail.originY"
    }

    public static let minimumWidth: Double = 160
    public static let maximumWidth: Double = 380
    public static let defaultWidth: Double = 255

    private let defaults: UserDefaults

    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    @Published public var mode: RailMode {
        didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
    }

    @Published private var storedMinimumWindows: Int

    /// How many windows an app must have before the rail appears. `1` keeps it
    /// on screen even for single-window apps.
    ///
    /// Clamping happens in the setter rather than in a `didSet`: re-assigning a
    /// `@Published` property from its own observer recurses until the stack
    /// runs out.
    public var minimumWindows: Int {
        get { storedMinimumWindows }
        set {
            let clamped = max(1, newValue)
            guard clamped != storedMinimumWindows else { return }
            storedMinimumWindows = clamped
            defaults.set(clamped, forKey: Key.minimumWindows)
        }
    }

    @Published public var listedBundleIDs: [String] {
        didSet { defaults.set(listedBundleIDs, forKey: Key.listedBundleIDs) }
    }

    /// Whether the rail gets out of the way while a window fills the screen.
    ///
    /// On by default: a full-screen window is usually video or a presentation,
    /// and there is nothing to switch between in a full-screen space anyway.
    @Published public var hidesInFullScreen: Bool {
        didSet { defaults.set(hidesInFullScreen, forKey: Key.hidesInFullScreen) }
    }

    @Published public var positionMode: RailPositionMode {
        didSet {
            defaults.set(positionMode.rawValue, forKey: Key.positionMode)
            positionRevision &+= 1
        }
    }

    /// Vivaldi's rail as a row of workspace glyphs instead of a list of names.
    @Published public var vivaldiIconStrip: Bool {
        didSet { defaults.set(vivaldiIconStrip, forKey: Key.vivaldiIconStrip) }
    }

    /// Whether apps that keep their own internal states — Vivaldi's workspaces,
    /// for instance — contribute those as a further section beside their
    /// windows.
    ///
    /// Off by default: it leans on undocumented internals of the app in
    /// question and can break when that app updates.
    @Published public var appSpecificProviders: Bool {
        didSet { defaults.set(appSpecificProviders, forKey: Key.appSpecificProviders) }
    }

    @Published private var storedWidth: Double

    /// Rail width in points, clamped to a range that stays usable.
    public var width: Double {
        get { storedWidth }
        set {
            let clamped = min(max(newValue, Self.minimumWidth), Self.maximumWidth)
            guard clamped != storedWidth else { return }
            storedWidth = clamped
            defaults.set(clamped, forKey: Key.width)
        }
    }

    /// Bumped whenever the stored position changes. `savedOrigin` is computed,
    /// so without this a reset would silently clear the stored value and leave
    /// the panel sitting where it was.
    @Published private var positionRevision = 0

    /// Exposed because `width` is computed and therefore has no `$` projection
    /// of its own for observers outside the class.
    public var widthPublisher: AnyPublisher<Double, Never> {
        $storedWidth.eraseToAnyPublisher()
    }

    /// Fires when the saved position is written or cleared.
    public var positionPublisher: AnyPublisher<Int, Never> {
        $positionRevision.eraseToAnyPublisher()
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? true
        mode = (defaults.string(forKey: Key.mode).flatMap(RailMode.init(rawValue:))) ?? .allApps
        storedMinimumWindows = max(1, defaults.object(forKey: Key.minimumWindows) as? Int ?? 2)
        listedBundleIDs = defaults.stringArray(forKey: Key.listedBundleIDs) ?? []
        appSpecificProviders = defaults.object(forKey: Key.appSpecificProviders) as? Bool ?? false
        hidesInFullScreen = defaults.object(forKey: Key.hidesInFullScreen) as? Bool ?? true
        positionMode = (defaults.string(forKey: Key.positionMode)
            .flatMap(RailPositionMode.init(rawValue:))) ?? .perApp
        vivaldiIconStrip = defaults.object(forKey: Key.vivaldiIconStrip) as? Bool ?? false
        storedWidth = min(
            max(defaults.object(forKey: Key.width) as? Double ?? Self.defaultWidth, Self.minimumWidth),
            Self.maximumWidth
        )
    }

    // MARK: - Allow list

    public func isListed(_ bundleID: String) -> Bool {
        listedBundleIDs.contains(bundleID)
    }

    public func addListed(_ bundleID: String) {
        guard !bundleID.isEmpty, !listedBundleIDs.contains(bundleID) else { return }
        listedBundleIDs.append(bundleID)
    }

    public func removeListed(_ bundleID: String) {
        listedBundleIDs.removeAll { $0 == bundleID }
    }

    public func toggleListed(_ bundleID: String) {
        isListed(bundleID) ? removeListed(bundleID) : addListed(bundleID)
    }

    // MARK: - Panel positions

    /// Each panel remembers its own place. The rail of windows and the panel of
    /// an app's own states are separate objects on screen, so one being dragged
    /// says nothing about where the other belongs.
    ///
    /// Positions are keyed by the section a panel shows, which is the only
    /// identity a panel has.

    /// The shared position of the main rail.
    ///
    /// Kept as its own pair of keys because that is where it has always lived;
    /// installs that predate per-panel positions keep their placement.
    public var savedOrigin: CGPoint? {
        get { point(forKey: Key.originX, Key.originY) }
        set {
            defer { positionRevision &+= 1 }
            setPoint(newValue, forKey: Key.originX, Key.originY)
        }
    }

    /// Where the given panel should open for the given application.
    public func origin(for bundleIdentifier: String?, section: String) -> CGPoint? {
        switch positionMode {
        case .shared:
            return sharedOrigin(section: section)
        case .perApp:
            guard let bundleIdentifier else { return nil }
            let origins = originsByApp
            if let stored = origins[key(section: section, bundleIdentifier: bundleIdentifier)] {
                return stored
            }
            // Before panels had their own positions these were keyed by bundle
            // id alone, and they all belonged to the rail of windows.
            guard section == WindowRailProvider.sectionID else { return nil }
            return origins[bundleIdentifier]
        }
    }

    /// Records where the user dropped a panel.
    ///
    /// The shared position is updated in both modes, so switching to shared
    /// mode lands each panel where it was last dropped rather than at the edge.
    public func setOrigin(_ origin: CGPoint, for bundleIdentifier: String?, section: String) {
        if positionMode == .perApp, let bundleIdentifier {
            var origins = originsByApp
            origins[key(section: section, bundleIdentifier: bundleIdentifier)] = origin
            writeOriginsByApp(origins)
        }
        setSharedOrigin(origin, section: section)
    }

    /// Forgets every stored position, so every panel returns to its default.
    public func resetPositions() {
        writeOriginsByApp([:])
        defaults.removeObject(forKey: Key.sharedOrigins)
        savedOrigin = nil
    }

    private func key(section: String, bundleIdentifier: String) -> String {
        "\(section)\u{1}\(bundleIdentifier)"
    }

    private func sharedOrigin(section: String) -> CGPoint? {
        guard section != WindowRailProvider.sectionID else { return savedOrigin }
        guard let pair = sharedOrigins[section], pair.count == 2 else { return nil }
        return CGPoint(x: pair[0], y: pair[1])
    }

    private func setSharedOrigin(_ origin: CGPoint, section: String) {
        guard section != WindowRailProvider.sectionID else {
            savedOrigin = origin
            return
        }
        var origins = sharedOrigins
        origins[section] = [Double(origin.x), Double(origin.y)]
        defaults.set(origins, forKey: Key.sharedOrigins)
        positionRevision &+= 1
    }

    private var sharedOrigins: [String: [Double]] {
        defaults.dictionary(forKey: Key.sharedOrigins) as? [String: [Double]] ?? [:]
    }

    private var originsByApp: [String: CGPoint] {
        let raw = defaults.dictionary(forKey: Key.originsByApp) as? [String: [Double]] ?? [:]
        return raw.compactMapValues { pair in
            pair.count == 2 ? CGPoint(x: pair[0], y: pair[1]) : nil
        }
    }

    private func writeOriginsByApp(_ origins: [String: CGPoint]) {
        let raw = origins.mapValues { [Double($0.x), Double($0.y)] }
        defaults.set(raw, forKey: Key.originsByApp)
    }

    private func point(forKey xKey: String, _ yKey: String) -> CGPoint? {
        guard let x = defaults.object(forKey: xKey) as? Double,
              let y = defaults.object(forKey: yKey) as? Double
        else { return nil }
        return CGPoint(x: x, y: y)
    }

    private func setPoint(_ point: CGPoint?, forKey xKey: String, _ yKey: String) {
        guard let point else {
            defaults.removeObject(forKey: xKey)
            defaults.removeObject(forKey: yKey)
            return
        }
        defaults.set(Double(point.x), forKey: xKey)
        defaults.set(Double(point.y), forKey: yKey)
    }
}
