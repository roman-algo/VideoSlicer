import Foundation

enum FFmpegLocator {
    /// Common install locations (Apple Silicon Homebrew, Intel Homebrew, system).
    static let candidates = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]

    static func autoDetect() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

/// Shared ffmpeg path, persisted so both the Slice and Convert tabs agree.
enum FFmpegStore {
    private static let key = "ffmpegPath"

    static func current() -> String {
        if let saved = UserDefaults.standard.string(forKey: key),
           FileManager.default.isExecutableFile(atPath: saved) {
            return saved
        }
        return FFmpegLocator.autoDetect() ?? ""
    }

    static func set(_ path: String) {
        UserDefaults.standard.set(path, forKey: key)
    }

    static func isReady(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
