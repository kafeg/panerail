import Foundation

/// The default provider: the windows of whatever app is in front. Always part
/// of the rail, whatever else an app contributes.
public final class WindowRailProvider: RailItemProvider {
    public static let sectionID = "windows"

    private let source: WindowSource
    /// Rows are identified by number in the UI, so the elements needed to raise
    /// them are kept aside rather than carried through the view layer.
    private var windowsByID: [UInt64: WindowInfo] = [:]

    public init(source: WindowSource) {
        self.source = source
    }

    public func supports(_ app: FrontmostApp) -> Bool { true }

    public func section(for app: FrontmostApp) -> RailSection? {
        let windows = WindowList.normalize(source.windows(for: app.pid), appName: app.name)
        windowsByID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return RailSection(
            id: Self.sectionID,
            title: "Windows",
            items: windows.map {
                RailItem(id: $0.id, title: $0.title, isActive: $0.isFocused, isDimmed: $0.isMinimized)
            }
        )
    }

    @discardableResult
    public func activate(_ item: RailItem, in app: FrontmostApp) -> Bool {
        guard let window = windowsByID[item.id.value] else { return false }
        return source.raise(window, pid: app.pid)
    }
}
