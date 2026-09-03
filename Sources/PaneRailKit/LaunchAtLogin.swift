import Foundation
import ServiceManagement

/// Login-item registration via `SMAppService` (macOS 13+).
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns whether the requested state was reached. Registration fails for
    /// unsigned builds and for apps run from outside /Applications, which is
    /// normal during development.
    @discardableResult
    public static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
