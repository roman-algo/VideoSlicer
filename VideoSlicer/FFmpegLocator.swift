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
