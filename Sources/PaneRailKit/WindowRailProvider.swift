import Foundation

/// The default provider: the windows of whatever app is in front.
public final class WindowRailProvider: RailItemProvider {
    private let source: WindowSource
    /// Rows are identified by number in the UI, so the elements needed to raise
    /// them are kept aside rather than carried through the view layer.
    private var windowsByID: [UInt64: WindowInfo] = [:]

    public init(source: WindowSource) {
        self.source = source
    }

    public func supports(_ app: FrontmostApp) -> Bool { true }

    public func items(for app: FrontmostApp) -> [RailItem] {
        let windows = WindowList.normalize(source.windows(for: app.pid), appName: app.name)
        windowsByID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return windows.map {
            RailItem(id: $0.id, title: $0.title, isActive: $0.isFocused, isDimmed: $0.isMinimized)
        }
    }

    @discardableResult
    public func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        guard let window = windowsByID[item.id] else { return false }
        return source.raise(window, pid: app.pid)
    }
}
