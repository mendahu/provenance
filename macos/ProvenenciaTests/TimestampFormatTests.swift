import Foundation
import Testing
@testable import Provenencia

@Suite
struct TimestampFormatTests {
    @Test func parseAcceptsFractionalAndPlainRFC3339() {
        #expect(TimestampFormat.parse("2026-03-04T19:22:00.123Z") != nil)
        #expect(TimestampFormat.parse("2026-03-04T19:22:00Z") != nil)
        #expect(TimestampFormat.parse("not-a-date") == nil)
    }

    @Test func boardStampFallsBackToRawWhenUnparseable() {
        #expect(TimestampFormat.boardStamp("garbage") == "garbage")
    }

    @Test func boardStampIncludesDateTimeAndTimezoneSeparator() {
        let stamp = TimestampFormat.boardStamp("2026-03-04T19:22:00Z")
        #expect(stamp.contains("·"))
        #expect(stamp.contains("2026"))
    }

    @Test func abbreviatedDateTimeFallsBackToRawWhenUnparseable() {
        #expect(TimestampFormat.abbreviatedDateTime("nope") == "nope")
    }
}
