import Foundation

/// Runs ffmpeg once per clip. Lossless mode uses stream copy (`-c copy`):
/// no re-encoding, no quality loss, works regardless of file size.
enum CutEngine {

    enum Mode {
        /// Stream copy — instant, lossless. Cuts land on the nearest keyframe.
        case lossless
        /// Re-encode — frame-accurate cut points, slightly slower and not bit-exact.
        case preciseReencode
    }

    struct Result {
        let outputURL: URL
        let succeeded: Bool
        let message: String
    }

    /// Builds the ffmpeg argument list for one clip.
    static func arguments(ffmpeg: String, input: URL, output: URL, clip: Clip, mode: Mode) -> [String] {
        let start = TimeValue.format(clip.start)
        let duration = String(format: "%.3f", clip.duration)

        switch mode {
        case .lossless:
            // -ss before -i = fast input seeking; -c copy = no re-encode.
            return [
                "-hide_banner", "-loglevel", "error", "-y",
                "-ss", start,
                "-i", input.path,
                "-t", duration,
                "-map", "0",
                "-c", "copy",
                "-avoid_negative_ts", "make_zero",
                output.path
            ]
        case .preciseReencode:
            return [
                "-hide_banner", "-loglevel", "error", "-y",
                "-ss", start,
                "-i", input.path,
                "-t", duration,
                "-map", "0",
                "-c:v", "libx264", "-crf", "18", "-preset", "medium",
                "-c:a", "aac", "-b:a", "192k",
                output.path
            ]
        }
    }

    /// Runs ffmpeg for a single clip synchronously and returns the outcome.
    static func run(ffmpeg: String, input: URL, outputDir: URL, clip: Clip, mode: Mode) -> Result {
        let ext = input.pathExtension.isEmpty ? "mp4" : input.pathExtension
        let base = input.deletingPathExtension().lastPathComponent
        let fileName = String(format: "%@_%03d_%@.%@", base, clip.index, clip.name, ext)
        let output = outputDir.appendingPathComponent(fileName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = arguments(ffmpeg: ffmpeg, input: input, output: output, clip: clip, mode: mode)

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            return Result(outputURL: output, succeeded: false,
                          message: "Could not launch ffmpeg: \(error.localizedDescription)")
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return Result(outputURL: output, succeeded: true, message: "Saved \(fileName)")
        } else {
            let stderr = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = stderr.isEmpty ? "ffmpeg exited with code \(process.terminationStatus)" : stderr
            return Result(outputURL: output, succeeded: false, message: detail)
        }
    }
}
