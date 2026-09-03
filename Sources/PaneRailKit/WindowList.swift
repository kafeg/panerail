import Foundation

/// Turns a raw AX window list into what the rail should actually render.
public enum WindowList {
    public static func normalize(
        _ windows: [WindowInfo],
        appName: String,
        includeMinimized: Bool = true
    ) -> [WindowInfo] {
        var seen = Set<UInt64>()
        var result: [WindowInfo] = []

        for window in windows {
            guard includeMinimized || !window.isMinimized else { continue }
            // The AX API can hand back the same window twice while an app is
            // rearranging; the first occurrence carries the front-most ordering.
            guard seen.insert(window.id).inserted else { continue }
            result.append(
                WindowInfo(
                    id: window.id,
                    title: WindowTitle.display(rawTitle: window.title, appName: appName),
                    isMinimized: window.isMinimized,
                    isFocused: window.isFocused,
                    handle: window.handle
                )
            )
        }

        return result
    }
}
