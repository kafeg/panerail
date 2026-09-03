import AppKit
import PaneRailKit

/// Scripted content for `--demo`, used for UI work and screenshots.
///
/// Everything here is invented placeholder text. Never put real window titles
/// or paths in this file: it is compiled into the binary and rendered into the
/// screenshots committed to the repository.
enum DemoData {
    static let pid: pid_t = 4242

    static let app = FrontmostApp(
        pid: pid,
        bundleIdentifier: "com.example.code",
        name: "Code",
        icon: makeIcon()
    )

    /// Drawn rather than borrowed: the demo must not depend on any particular
    /// app being installed, and must not put someone else's logo into the
    /// screenshots committed here.
    private static func makeIcon() -> NSImage {
        let side: CGFloat = 32
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).setClip()
            NSGradient(
                starting: NSColor(calibratedRed: 0.29, green: 0.56, blue: 0.90, alpha: 1),
                ending: NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.72, alpha: 1)
            )?.draw(in: rect, angle: -90)

            guard let symbol = NSImage(
                systemSymbolName: "chevron.left.forwardslash.chevron.right",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) else { return true }

            let glyph = NSImage(size: symbol.size, flipped: false) { glyphRect in
                symbol.draw(in: glyphRect)
                NSColor.white.set()
                glyphRect.fill(using: .sourceAtop)
                return true
            }
            glyph.draw(in: NSRect(
                x: (side - symbol.size.width) / 2,
                y: (side - symbol.size.height) / 2,
                width: symbol.size.width,
                height: symbol.size.height
            ))
            return true
        }
    }

    static func makeSource() -> WindowSource {
        FakeWindowSource(windowsByPID: [
            pid: [
                WindowInfo(id: 1, title: "hello-world — main.swift", isFocused: true),
                WindowInfo(id: 2, title: "example-site — index.html"),
                WindowInfo(id: 3, title: "sandbox — docker-compose.yml"),
                WindowInfo(id: 4, title: "scratch.txt"),
                WindowInfo(id: 5, title: "demo — README.md", isMinimized: true),
            ],
        ])
    }
}
