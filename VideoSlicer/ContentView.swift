import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = SlicerModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            videoRow
            jsonSection
            outputRow
            optionsRow

            Divider()

            actionRow

            if !model.clips.isEmpty || !model.log.isEmpty {
                resultArea
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear { model.refreshClips() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("VideoSlicer")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Cut a video into clips losslessly, straight from a list of timestamps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Video

    private var videoRow: some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Source video").font(.headline)
                    Text(model.videoURL?.lastPathComponent ?? "Drop a file here or choose one — any length or size.")
                        .font(.callout)
                        .foregroundStyle(model.videoURL == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose…") { pickVideo() }
            }
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
        }
    }

    // MARK: - JSON

    private var jsonSection: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Timestamps (JSON)").font(.headline)
                    Spacer()
                    Button("Load file…") { pickJSON() }
                    Button("Insert sample") {
                        model.jsonText = SlicerModel.sampleJSON
                        model.refreshClips()
                    }
                }
                TextEditor(text: $model.jsonText)
                    .font(.system(.callout, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 180)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                    .onChange(of: model.jsonText) { _ in model.refreshClips() }
                Text("Each item: \"start\" and \"end\" (or \"duration\"), optional \"name\". Times as \"HH:MM:SS.mmm\" or seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Output

    private var outputRow: some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save clips to").font(.headline)
                    Text(model.outputDir?.path ?? "No folder chosen yet.")
                        .font(.callout)
                        .foregroundStyle(model.outputDir == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Choose…") { pickOutput() }
            }
        }
    }

    // MARK: - Options

    private var optionsRow: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $model.preciseMode) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Frame-accurate cuts (re-encode)")
                        Text(model.preciseMode
                             ? "Exact cut points, slower, re-encodes the video."
                             : "Lossless stream copy — instant, no quality loss, cuts snap to keyframes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Circle()
                        .fill(model.ffmpegReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(model.ffmpegReady ? "ffmpeg: \(model.ffmpegPath)" : "ffmpeg not found — install it or pick it manually.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Set ffmpeg…") { pickFFmpeg() }
                }
            }
        }
    }

    // MARK: - Action

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button(action: { model.start() }) {
                Text(model.isRunning ? "Cutting…" : "Cut \(model.clips.count) clip\(model.clips.count == 1 ? "" : "s")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canStart || model.clips.isEmpty)

            if model.isRunning {
                ProgressView(value: Double(model.completedCount), total: Double(max(model.clips.count, 1)))
                    .frame(width: 160)
            }
        }
    }

    // MARK: - Results

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.statusLine).font(.callout).foregroundStyle(.secondary)
                Spacer()
                if model.outputDir != nil && model.completedCount > 0 {
                    Button("Reveal in Finder") { model.revealOutput() }
                }
            }

            if !model.clips.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.clips) { clip in
                            clipRow(clip)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }

    private func clipRow(_ clip: Clip) -> some View {
        HStack(spacing: 10) {
            statusIcon(clip.status)
            Text(String(format: "%03d", clip.index))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(clip.name).font(.callout)
            Spacer()
            Text("\(clip.startLabel) → \(clip.endLabel)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func statusIcon(_ status: Clip.Status) -> some View {
        switch status {
        case .queued:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }

    // MARK: - Card container

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }

    // MARK: - File pickers

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK, let url = panel.url {
            model.videoURL = url
        }
    }

    private func pickJSON() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json, .text]
        if panel.runModal() == .OK, let url = panel.url,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            model.jsonText = text
            model.refreshClips()
        }
    }

    private func pickOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            model.outputDir = url
        }
    }

    private func pickFFmpeg() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        panel.message = "Select the ffmpeg executable"
        if panel.runModal() == .OK, let url = panel.url {
            model.setFFmpeg(url.path)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url {
                DispatchQueue.main.async { model.videoURL = url }
            }
        }
        return true
    }
}

#Preview {
    ContentView()
}
