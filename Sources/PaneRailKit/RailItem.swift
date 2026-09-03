import Foundation

/// One row of the rail.
///
/// The rail used to render windows directly; it now renders whatever the
/// provider for the current app supplies, which for Vivaldi is workspaces.
public struct RailItem: Identifiable, Equatable {
    public let id: UInt64
    public let title: String
    /// The row the user is currently "in", when that is knowable.
    public let isActive: Bool
    /// Drawn muted — minimised windows, for instance.
    public let isDimmed: Bool

    public init(id: UInt64, title: String, isActive: Bool = false, isDimmed: Bool = false) {
        self.id = id
        self.title = title
        self.isActive = isActive
        self.isDimmed = isDimmed
    }
}

/// Supplies the rail's rows for a given application and acts on a click.
///
/// Providers are asked in order and the first one that claims the app wins, so
/// an app-specific provider takes precedence over plain window switching.
public protocol RailItemProvider: AnyObject {
    /// Whether this provider can describe the given app right now. Returning
    /// false — because a browser profile could not be read, say — lets the
    /// window provider take over instead of leaving the rail empty.
    func supports(_ app: FrontmostApp) -> Bool

    func items(for app: FrontmostApp) -> [RailItem]

    @discardableResult
    func activate(_ item: RailItem, in app: FrontmostApp) -> Bool
}
