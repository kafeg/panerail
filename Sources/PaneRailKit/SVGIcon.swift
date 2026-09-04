import AppKit
import CoreGraphics

/// A tiny SVG reader, covering exactly the shapes Vivaldi stores for workspace
/// icons: a `viewBox`, some `<path>` elements and the odd `<line>`, with only
/// absolute path commands.
///
/// It is not a general SVG implementation and is not meant to become one. The
/// alternative — rendering through a web view — would mean an asynchronous,
/// far heavier dependency for a 16-point glyph.
public struct SVGIcon: Equatable {
    public let viewBox: CGRect
    public let path: CGPath

    public static func == (lhs: SVGIcon, rhs: SVGIcon) -> Bool {
        lhs.viewBox == rhs.viewBox && lhs.path == rhs.path
    }
}

public enum SVGIconParser {
    public static func parse(_ svg: String) -> SVGIcon? {
        let box = viewBox(in: svg) ?? CGRect(x: 0, y: 0, width: 16, height: 16)
        let path = CGMutablePath()
        var isEmpty = true

        for d in attributes(named: "d", in: svg) {
            guard let sub = SVGPath.parse(d) else { continue }
            path.addPath(sub)
            isEmpty = false
        }

        for line in elements(named: "line", in: svg) {
            guard let x1 = number(named: "x1", in: line), let y1 = number(named: "y1", in: line),
                  let x2 = number(named: "x2", in: line), let y2 = number(named: "y2", in: line)
            else { continue }
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
            isEmpty = false
        }

        guard !isEmpty else { return nil }
        return SVGIcon(viewBox: box, path: path)
    }

    private static func viewBox(in svg: String) -> CGRect? {
        guard let raw = attributes(named: "viewBox", in: svg).first else { return nil }
        let parts = raw.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private static func attributes(named name: String, in svg: String) -> [String] {
        var results: [String] = []
        var search = svg[...]
        while let range = search.range(of: "\(name)=\"") {
            let rest = search[range.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else { break }
            results.append(String(rest[..<end]))
            search = rest[rest.index(after: end)...]
        }
        return results
    }

    private static func elements(named name: String, in svg: String) -> [String] {
        var results: [String] = []
        var search = svg[...]
        while let range = search.range(of: "<\(name)") {
            let rest = search[range.upperBound...]
            guard let end = rest.firstIndex(of: ">") else { break }
            results.append(String(rest[..<end]))
            search = rest[rest.index(after: end)...]
        }
        return results
    }

    private static func number(named name: String, in element: String) -> CGFloat? {
        guard let raw = attributes(named: name, in: element).first,
              let value = Double(raw) else { return nil }
        return CGFloat(value)
    }
}

/// Path data reader for the commands Vivaldi's icons actually use.
enum SVGPath {
    static func parse(_ d: String) -> CGPath? {
        let path = CGMutablePath()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var scanner = Scanner(string: d)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n\t\r")

        func next() -> CGFloat? {
            guard let value = scanner.scanDouble() else { return nil }
            return CGFloat(value)
        }

        while !scanner.isAtEnd {
            guard let command = scanner.scanCharacter() else { break }
            let relative = command.isLowercase
            let origin = relative ? current : .zero

            switch Character(command.lowercased()) {
            case "m":
                guard let x = next(), let y = next() else { return nil }
                current = CGPoint(x: origin.x + x, y: origin.y + y)
                start = current
                path.move(to: current)
            case "l":
                guard let x = next(), let y = next() else { return nil }
                current = CGPoint(x: origin.x + x, y: origin.y + y)
                path.addLine(to: current)
            case "h":
                guard let x = next() else { return nil }
                current = CGPoint(x: origin.x + x, y: current.y)
                path.addLine(to: current)
            case "v":
                guard let y = next() else { return nil }
                current = CGPoint(x: current.x, y: origin.y + y)
                path.addLine(to: current)
            case "c":
                guard let x1 = next(), let y1 = next(),
                      let x2 = next(), let y2 = next(),
                      let x = next(), let y = next() else { return nil }
                let end = CGPoint(x: origin.x + x, y: origin.y + y)
                path.addCurve(
                    to: end,
                    control1: CGPoint(x: origin.x + x1, y: origin.y + y1),
                    control2: CGPoint(x: origin.x + x2, y: origin.y + y2)
                )
                current = end
            case "z":
                path.closeSubpath()
                current = start
            default:
                // An unsupported command would silently distort the rest of the
                // shape, so the whole icon is dropped instead.
                return nil
            }
        }

        return path.isEmpty ? nil : path
    }
}
