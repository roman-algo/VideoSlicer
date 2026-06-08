import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConvertView: View {
    @StateObject private var model = ConvertModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            fileList
            outputRow
            optionsRow
            Divider()
            actionRow
            statusRow
            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear { model.refreshFFmpeg() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Convert to MP4")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Lossless container remux — copies the original streams into MP4, no re-encoding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var fileList: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Files").font(.headline)
                    Spacer()
                    if !model.items.isEmpty {
                        Button("Clear") { model.clear() }
                    }
                    Button("Add files…") { pickFiles() }
                }

                if model.items.isEmpty {
                    Text("Drop .mkv (or other) video files here, or click Add files…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(model.items) { item in
                                itemRow(item)
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in handleDrop(providers) }
        }
    }

    private func itemRow(_ item: ConvertItem) -> some View {
        HStack(spacing: 10) {
            statusIcon(item.status)
            Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
            Spacer()
            if !model.isRunning {
                Button {
                    model.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func statusIcon(_ status: ConvertItem.Status) -> some View {
        switch status {
        case .queued: Image(systemName: "circle").foregroundStyle(.secondary)
        case .running: ProgressView().controlSize(.small)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let m): Image(systemName: "xmark.circle.fill").foregroundStyle(.red).help(m)
        }
    }

    private var outputRow: some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "folder").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save MP4s to").font(.headline)
                    Text(model.outputDir?.path ?? "Same folder as each source file.")
                        .font(.callout)
                        .foregroundStyle(model.outputDir == nil ? .secondary : .primary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if model.outputDir != nil {
                    Button("Use source folder") { model.outputDir = nil }
                }
                Button("Choose…") { pickOutput() }
            }
        }
    }

    private var optionsRow: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $model.includeSubtitles) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Keep text subtitles (convert to mov_text)")
                        Text("Off is safest. Image-based subs (PGS/VOBSUB) can't go in MP4 and will fail if on.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Circle().fill(model.ffmpegReady ? Color.green : Color.orange).frame(width: 8, height: 8)
                    Text(model.ffmpegReady ? "ffmpeg: \(model.ffmpegPath)" : "ffmpeg not found — install it or pick it manually.")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Set ffmpeg…") { pickFFmpeg() }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button(action: { model.start() }) {
                Text(model.isRunning ? "Converting…" : "Convert \(model.items.count) file\(model.items.count == 1 ? "" : "s")")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStart)

            if model.isRunning {
                ProgressView(value: Double(model.completedCount), total: Double(max(model.items.count, 1)))
                    .frame(width: 160)
            }
        }
    }

    private var statusRow: some View {
        HStack {
            Text(model.statusLine).font(.callout).foregroundStyle(.secondary)
            Spacer()
            if model.completedCount > 0 {
                Button("Reveal in Finder") { model.revealOutput() }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - Pickers

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, UTType("org.matroska.mkv") ?? .movie]
        if panel.runModal() == .OK {
            model.addFiles(panel.urls)
        }
    }

    private func pickOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { model.outputDir = url }
    }

    private func pickFFmpeg() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        panel.message = "Select the ffmpeg executable"
        if panel.runModal() == .OK, let url = panel.url { model.setFFmpeg(url.path) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            handled = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL {
                    DispatchQueue.main.async { model.addFiles([url]) }
                }
            }
        }
        return handled
    }
}

#Preview {
    ConvertView()
}
