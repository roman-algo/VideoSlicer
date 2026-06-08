import Foundation

/// Remuxes a file into an MP4 container losslessly (`-c copy`): the original
/// video and audio streams are copied byte-for-byte, only the wrapper changes.
enum ConvertEngine {

    struct Result {
        let outputURL: URL
        let succeeded: Bool
        let message: String
    }

    static func arguments(input: URL, output: URL, includeSubtitles: Bool) -> [String] {
        var args = [
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", input.path,
            "-map", "0:v?",
            "-map", "0:a?"
        ]
        if includeSubtitles {
            // Text subtitles -> MP4's mov_text. (Image subs like PGS can't go in MP4.)
            args += ["-map", "0:s?", "-c", "copy", "-c:s", "mov_text"]
        } else {
            args += ["-c", "copy"]
        }
        args += ["-movflags", "+faststart", output.path]
        return args
    }

    /// Converts a single file. Output goes to `outputDir` if given, else next to
    /// the source. The `.mp4` extension replaces the original.
    static func run(ffmpeg: String, input: URL, outputDir: URL?, includeSubtitles: Bool) -> Result {
        let base = input.deletingPathExtension().lastPathComponent
        let dir = outputDir ?? input.deletingLastPathComponent()
        let output = dir.appendingPathComponent(base + ".mp4")

        // Never let the output clobber the input (e.g. an .mp4 already in place).
        if output.path == input.path {
            return Result(outputURL: output, succeeded: false,
                          message: "Source is already \"\(output.lastPathComponent)\" — pick a different output folder.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = arguments(input: input, output: output, includeSubtitles: includeSubtitles)

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
            return Result(outputURL: output, succeeded: true, message: "Saved \(output.lastPathComponent)")
        } else {
            let stderr = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let detail = stderr.isEmpty ? "ffmpeg exited with code \(process.terminationStatus)" : stderr
            return Result(outputURL: output, succeeded: false, message: detail)
        }
    }
}
