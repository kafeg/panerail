import Foundation

/// Identifies a row across the whole rail.
///
/// The value alone is only unique within the provider that produced it: window
/// ids are accessibility element hashes, workspace ids are positions in a list.
/// Once the rail shows more than one provider at a time those spaces overlap,
/// and a collision would route a click to the wrong place or highlight two rows
/// at once. Scoping by section makes that impossible rather than unlikely.
public struct RailItemID: Hashable {
    public let section: String
    public let value: UInt64

    public init(section: String, value: UInt64) {
        self.section = section
        self.value = value
    }
}

/// One row of the rail.
public struct RailItem: Identifiable, Equatable {
    /// Scoped by the section that adopts the item, not by the provider that
    /// built it — providers go on using their own numbering.
    public internal(set) var id: RailItemID
    public let title: String
    /// The row the user is currently "in", when that is knowable.
    public let isActive: Bool
    /// Drawn muted — minimised windows, for instance.
    public let isDimmed: Bool
    /// Inline SVG for a glyph to show instead of the row's plain marker, when
    /// the provider has one. Carried as markup rather than an image so the item
    /// stays a comparable value.
    public let iconSVG: String?

    public init(
        id: UInt64,
        title: String,
        isActive: Bool = false,
        isDimmed: Bool = false,
        iconSVG: String? = nil
    ) {
        self.id = RailItemID(section: "", value: id)
        self.title = title
        self.isActive = isActive
        self.isDimmed = isDimmed
        self.iconSVG = iconSVG
    }

    func scoped(to section: String) -> RailItem {
        var copy = self
        copy.id = RailItemID(section: section, value: id.value)
        return copy
    }
}

/// How a section arranges its rows.
public enum RailLayout: String, Equatable, Codable {
    /// A vertical list of titles — the only sensible shape for window titles.
    case list
    /// A row of glyphs, with no titles. Only worth offering when every row has
    /// an icon that identifies it on its own.
    case glyphs
}

/// A group of rows within the rail, with its own shape and its own provider.
public struct RailSection: Identifiable, Equatable {
    public let id: String
    /// Shown only when the rail has more than one section; a single section
    /// needs no label, and the rail must look unchanged for apps that have one.
    public let title: String
    public let layout: RailLayout
    public let items: [RailItem]

    public init(id: String, title: String, layout: RailLayout = .list, items: [RailItem]) {
        self.id = id
        self.title = title
        self.layout = layout
        self.items = items.map { $0.scoped(to: id) }
    }
}

/// Contributes a section of rows for a given application, and acts on a click.
///
/// Providers contribute rather than compete: the window provider is always
/// asked, and an app-specific one adds to it. Replacing windows outright would
/// take away the ability to switch between an app's windows at the very moment
/// it has several — a browser with a private window alongside a normal one, say.
public protocol RailItemProvider: AnyObject {
    /// Whether this provider has anything to say about the given app right now.
    /// Returning false — because a browser profile could not be read, say —
    /// simply leaves its section out.
    func supports(_ app: FrontmostApp) -> Bool

    /// The section to contribute, or `nil` for nothing.
    func section(for app: FrontmostApp) -> RailSection?

    @discardableResult
    func activate(_ item: RailItem, in app: FrontmostApp) -> Bool
}
