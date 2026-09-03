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
        icon: NSImage(named: NSImage.applicationIconName)
    )

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
