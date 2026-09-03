import AppKit

// A plain `main.swift` rather than `@main`: the app is an accessory that lives
// entirely in a floating panel, so the SwiftUI app lifecycle would only get in
// the way of managing an `NSPanel` by hand.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
