import Foundation

/// Shared RFC 3339 → display formatting for catalog timestamps.
///
/// Formatters are cached and guarded: `ISO8601DateFormatter` is not safe for
/// concurrent use on the same instance.
enum TimestampFormat {
    private static let lock = NSLock()
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ rfc3339: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return withFraction.date(from: rfc3339) ?? plain.date(from: rfc3339)
    }

    /// Board stamp used on note rows: `04 Mar 2026 · 7:22 PM MST`.
    static func boardStamp(_ rfc3339: String) -> String {
        guard let date = parse(rfc3339) else { return rfc3339 }
        let datePart = date.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year())
        let timePart = date.formatted(.dateTime.hour().minute().timeZone(.specificName(.short)))
        return "\(datePart) · \(timePart)"
    }

    /// Compact absolute date+time (onboarding project meta, etc.).
    static func abbreviatedDateTime(_ rfc3339: String) -> String {
        guard let date = parse(rfc3339) else { return rfc3339 }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
