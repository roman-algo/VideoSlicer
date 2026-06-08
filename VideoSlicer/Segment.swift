import Foundation

/// One entry as written in the user's JSON.
struct InputSegment: Decodable {
    let name: String?
    let start: TimeValue
    let end: TimeValue?
    let duration: TimeValue?
}

/// A validated, ready-to-cut clip.
struct Clip: Identifiable {
    enum Status: Equatable {
        case queued
        case running
        case done
        case failed(String)
    }

    let id = UUID()
    let index: Int
    let name: String
    let start: Double
    let duration: Double
    var status: Status = .queued

    var startLabel: String { TimeValue.format(start) }
    var endLabel: String { TimeValue.format(start + duration) }
}

enum SegmentParser {
    /// Decodes the JSON text and resolves every entry into a `Clip`.
    /// Throws a human-readable error on the first problem found.
    static func parse(_ json: String) throws -> [Clip] {
        let text = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ParseError.message("Paste your timestamps JSON first.")
        }
        guard let data = text.data(using: .utf8) else {
            throw ParseError.message("Could not read the JSON text.")
        }

        let raw: [InputSegment]
        do {
            raw = try JSONDecoder().decode([InputSegment].self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            throw ParseError.message(context.debugDescription)
        } catch {
            throw ParseError.message(
                "JSON must be an array of objects like " +
                "[{\"name\":\"intro\",\"start\":\"00:01:05\",\"end\":\"00:01:12\"}]."
            )
        }

        guard !raw.isEmpty else {
            throw ParseError.message("The JSON array is empty — nothing to cut.")
        }

        var clips: [Clip] = []
        for (i, segment) in raw.enumerated() {
            let humanIndex = i + 1
            let start = segment.start.seconds

            let duration: Double
            if let end = segment.end {
                duration = end.seconds - start
            } else if let dur = segment.duration {
                duration = dur.seconds
            } else {
                throw ParseError.message("Segment #\(humanIndex) needs an \"end\" or \"duration\".")
            }

            guard start >= 0 else {
                throw ParseError.message("Segment #\(humanIndex) has a negative start time.")
            }
            guard duration > 0 else {
                throw ParseError.message("Segment #\(humanIndex) ends at or before it starts.")
            }

            let cleanName = (segment.name ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = cleanName.isEmpty ? "clip" : sanitize(cleanName)

            clips.append(Clip(index: humanIndex, name: safeName, start: start, duration: duration))
        }
        return clips
    }

    /// Strips characters that are awkward in file names.
    static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.replacingOccurrences(of: " ", with: "_")
    }

    enum ParseError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self { case .message(let m): return m }
        }
    }
}
