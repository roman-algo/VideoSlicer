import Foundation

/// A timestamp that can be decoded either from a number of seconds
/// (e.g. `95.5`) or from a clock string (`"HH:MM:SS.mmm"`, `"MM:SS"`, `"SS"`).
struct TimeValue: Decodable {
    let seconds: Double

    init(seconds: Double) { self.seconds = seconds }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            seconds = number
            return
        }
        if let string = try? container.decode(String.self) {
            guard let parsed = TimeValue.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid time value: \"\(string)\""
                )
            }
            seconds = parsed
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Time must be a number of seconds or a \"HH:MM:SS\" string"
        )
    }

    /// Parses "HH:MM:SS.mmm", "MM:SS", or "SS(.mmm)" into seconds.
    static func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        var total = 0.0
        for part in parts {
            guard let value = Double(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }

    /// Formats seconds as `HH:MM:SS.mmm` for ffmpeg arguments.
    static func format(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let hours = Int(clamped) / 3600
        let minutes = (Int(clamped) % 3600) / 60
        let secs = clamped - Double(hours * 3600 + minutes * 60)
        return String(format: "%02d:%02d:%06.3f", hours, minutes, secs)
    }
}
