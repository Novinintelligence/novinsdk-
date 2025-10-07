import Foundation

enum NovinWM {
    // Stable UUID that you NEVER rotate; proves lineage
    static let lineageID = UUID(uuidString: "F1E8D6E2-9C3A-4FB1-8D3E-74B42A5EC7B3")!

    // Rotating build IDs per release (set by build script)
    static let buildID: String = {
        #if NOVIN_BUILD_ID
        return String(cString: NOVIN_BUILD_ID) // injected via -D
        #else
        return "DEV-LOCAL"
        #endif
    }()

    // Canary strings split to avoid simple grep removal
    static var canary: String {
        let parts = ["n0", "v1", "n:", "ai:", "wm:", "©", "2025"]
        return parts.joined()
    }
}

// Touch at runtime so it isn’t dead-stripped
@inline(never)
public func novinWatermarkTouch() {
    _ = NovinWM.lineageID
    _ = NovinWM.buildID
    _ = NovinWM.canary.hashValue
}
