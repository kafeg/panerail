import AppKit

/// Draws a parsed icon into a template image, cached by shape and size.
///
/// Template images take their colour from whatever draws them, which is what
/// lets one workspace glyph sit correctly in both light and dark appearances
/// and turn accent-coloured when its row is the active one.
public final class SVGIconRenderer {
    public static let shared = SVGIconRenderer()

    private var cache: [Key: NSImage] = [:]
    private let lock = NSLock()

    private struct Key: Hashable {
        let svg: String
        let side: CGFloat
    }

    public init() {}

    public func image(svg: String, side: CGFloat = 13) -> NSImage? {
        let key = Key(svg: svg, side: side)

        lock.lock()
        let cached = cache[key]
        lock.unlock()
        if let cached { return cached }

        guard let icon = SVGIconParser.parse(svg) else { return nil }
        let image = Self.draw(icon, side: side)

        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }

    private static func draw(_ icon: SVGIcon, side: CGFloat) -> NSImage {
        // The stroke is scaled with the glyph and half of it falls outside the
        // path, so the drawing is inset to keep it from clipping at the edges.
        let strokeWidth: CGFloat = 1.25
        let scale = side / max(icon.viewBox.width, icon.viewBox.height)
        let inset = strokeWidth * scale / 2

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }

            context.translateBy(x: inset, y: side - inset)
            context.scaleBy(x: 1, y: -1)
            let drawable = side - inset * 2
            context.scaleBy(
                x: drawable / icon.viewBox.width,
                y: drawable / icon.viewBox.height
            )
            context.translateBy(x: -icon.viewBox.minX, y: -icon.viewBox.minY)

            context.setLineWidth(strokeWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setStrokeColor(NSColor.black.cgColor)
            context.addPath(icon.path)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
