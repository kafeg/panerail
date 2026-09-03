import AppKit

/// Snapshot of the application the rail is currently describing.
public struct FrontmostApp: Equatable {
    public let pid: pid_t
    public let bundleIdentifier: String?
    public let name: String
    public let icon: NSImage?

    public init(pid: pid_t, bundleIdentifier: String?, name: String, icon: NSImage? = nil) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.icon = icon
    }

    public init?(running: NSRunningApplication) {
        guard running.processIdentifier > 0 else { return nil }
        self.init(
            pid: running.processIdentifier,
            bundleIdentifier: running.bundleIdentifier,
            name: running.localizedName ?? running.bundleIdentifier ?? "Application",
            icon: running.icon
        )
    }

    public static func == (lhs: FrontmostApp, rhs: FrontmostApp) -> Bool {
        lhs.pid == rhs.pid && lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.name == rhs.name
    }
}

/// Tracks which application is in front, ignoring our own so that clicking the
/// rail never changes what the rail is showing.
public final class FrontmostAppMonitor {
    public var onChange: ((FrontmostApp?) -> Void)?
    public private(set) var current: FrontmostApp?

    private let ignoredPIDs: Set<pid_t>
    private var observers: [NSObjectProtocol] = []

    public init(ignoring ignoredPIDs: Set<pid_t> = [ProcessInfo.processInfo.processIdentifier]) {
        self.ignoredPIDs = ignoredPIDs
    }

    deinit { stop() }

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.handleActivation(app)
        })

        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier == self.current?.pid
            else { return }
            self.current = nil
            self.onChange?(nil)
        })

        handleActivation(NSWorkspace.shared.frontmostApplication)
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    private func handleActivation(_ running: NSRunningApplication?) {
        guard let running, !ignoredPIDs.contains(running.processIdentifier) else { return }
        guard let app = FrontmostApp(running: running) else { return }
        guard app != current else { return }
        current = app
        onChange?(app)
    }
}
