import Foundation
import SwiftUI
import AppKit

struct ConvertItem: Identifiable {
    enum Status: Equatable {
        case queued
        case running
        case done
        case failed(String)
    }
    let id = UUID()
    let url: URL
    var status: Status = .queued
    var name: String { url.lastPathComponent }
}

@MainActor
final class ConvertModel: ObservableObject {
    @Published var items: [ConvertItem] = []
    @Published var outputDir: URL?            // nil = save next to each source
    @Published var includeSubtitles = false
    @Published var ffmpegPath: String = FFmpegStore.current()

    @Published var isRunning = false
    @Published var completedCount = 0
    @Published var statusLine = "Add one or more video files to convert to MP4."

    var ffmpegReady: Bool { FFmpegStore.isReady(ffmpegPath) }
    var canStart: Bool { !items.isEmpty && ffmpegReady && !isRunning }

    func refreshFFmpeg() { ffmpegPath = FFmpegStore.current() }

    func setFFmpeg(_ path: String) {
        ffmpegPath = path
        FFmpegStore.set(path)
    }

    func addFiles(_ urls: [URL]) {
        let existing = Set(items.map { $0.url })
        for url in urls where !existing.contains(url) {
            items.append(ConvertItem(url: url))
        }
        statusLine = "\(items.count) file\(items.count == 1 ? "" : "s") ready."
    }

    func remove(_ item: ConvertItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
        completedCount = 0
        statusLine = "Add one or more video files to convert to MP4."
    }

    func start() {
        guard ffmpegReady, !items.isEmpty else { return }
        isRunning = true
        completedCount = 0
        for i in items.indices { items[i].status = .queued }

        let ffmpeg = ffmpegPath
        let outDir = outputDir
        let subs = includeSubtitles
        let snapshot = items

        Task.detached { [weak self] in
            for item in snapshot {
                await self?.mark(item.id, .running)
                let result = ConvertEngine.run(
                    ffmpeg: ffmpeg, input: item.url, outputDir: outDir, includeSubtitles: subs
                )
                if result.succeeded {
                    await self?.mark(item.id, .done)
                    await self?.bump()
                } else {
                    await self?.mark(item.id, .failed(result.message))
                }
            }
            await self?.finish()
        }
    }

    private func mark(_ id: UUID, _ status: ConvertItem.Status) {
        if let i = items.firstIndex(where: { $0.id == id }) { items[i].status = status }
    }
    private func bump() { completedCount += 1 }

    private func finish() {
        isRunning = false
        let failures = items.filter { if case .failed = $0.status { return true }; return false }.count
        statusLine = failures == 0
            ? "Done — \(completedCount) file\(completedCount == 1 ? "" : "s") converted."
            : "Finished with \(failures) failed, \(completedCount) converted."
    }

    func revealOutput() {
        let url = outputDir ?? items.first?.url.deletingLastPathComponent()
        if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}
