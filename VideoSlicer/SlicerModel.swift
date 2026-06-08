import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SlicerModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var outputDir: URL?
    @Published var jsonText: String = SlicerModel.sampleJSON
    @Published var clips: [Clip] = []

    @Published var ffmpegPath: String = ""
    @Published var preciseMode: Bool = false

    @Published var isRunning = false
    @Published var completedCount = 0
    @Published var statusLine = "Ready."
    @Published var log: [String] = []

    private let ffmpegDefaultsKey = "ffmpegPath"

    init() {
        if let saved = UserDefaults.standard.string(forKey: ffmpegDefaultsKey),
           FileManager.default.isExecutableFile(atPath: saved) {
            ffmpegPath = saved
        } else if let detected = FFmpegLocator.autoDetect() {
            ffmpegPath = detected
        }
    }

    var ffmpegReady: Bool { FileManager.default.isExecutableFile(atPath: ffmpegPath) }

    var canStart: Bool {
        videoURL != nil && outputDir != nil && ffmpegReady && !isRunning
    }

    func setFFmpeg(_ path: String) {
        ffmpegPath = path
        UserDefaults.standard.set(path, forKey: ffmpegDefaultsKey)
    }

    /// Re-parses the JSON and refreshes the preview list.
    @discardableResult
    func refreshClips() -> Bool {
        do {
            clips = try SegmentParser.parse(jsonText)
            statusLine = "\(clips.count) segment\(clips.count == 1 ? "" : "s") ready."
            return true
        } catch {
            clips = []
            statusLine = error.localizedDescription
            return false
        }
    }

    func start() {
        guard let videoURL, let outputDir, ffmpegReady else { return }
        guard refreshClips(), !clips.isEmpty else { return }

        isRunning = true
        completedCount = 0
        log.removeAll()
        for i in clips.indices { clips[i].status = .queued }

        let mode: CutEngine.Mode = preciseMode ? .preciseReencode : .lossless
        let ffmpeg = ffmpegPath
        let snapshot = clips

        Task.detached { [weak self] in
            for clip in snapshot {
                await self?.mark(clip.id, .running)
                await self?.append("Cutting #\(clip.index) \(clip.name)  [\(clip.startLabel) → \(clip.endLabel)]")

                let result = CutEngine.run(
                    ffmpeg: ffmpeg, input: videoURL, outputDir: outputDir, clip: clip, mode: mode
                )

                if result.succeeded {
                    await self?.mark(clip.id, .done)
                    await self?.append("  ✓ \(result.message)")
                    await self?.bumpCompleted()
                } else {
                    await self?.mark(clip.id, .failed(result.message))
                    await self?.append("  ✗ \(result.message)")
                }
            }
            await self?.finish()
        }
    }

    private func mark(_ id: UUID, _ status: Clip.Status) {
        if let i = clips.firstIndex(where: { $0.id == id }) {
            clips[i].status = status
        }
    }

    private func append(_ line: String) { log.append(line) }
    private func bumpCompleted() { completedCount += 1 }

    private func finish() {
        isRunning = false
        let failures = clips.filter { if case .failed = $0.status { return true }; return false }.count
        if failures == 0 {
            statusLine = "Done — \(completedCount) clip\(completedCount == 1 ? "" : "s") saved."
        } else {
            statusLine = "Finished with \(failures) failed, \(completedCount) saved."
        }
    }

    func revealOutput() {
        if let outputDir { NSWorkspace.shared.activateFileViewerSelecting([outputDir]) }
    }

    static let sampleJSON = """
    [
      { "name": "intro",      "start": "00:00:05",     "end": "00:00:18.500" },
      { "name": "highlight",  "start": "01:12:40",     "end": "01:12:52" },
      { "name": "outro",      "start": 7200,           "end": 7212.25 }
    ]
    """
}
