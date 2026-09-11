import Foundation
import Testing
@testable import Provenencia

/// Asserts `DateValueDraft.summary` matches Go `datevalues.FormatSummary`
/// for the shared fixture file at `testdata/datevalues/format_summary.json`.
@Suite
struct DateValueSummaryParityTests {
    private struct Fixture: Decodable {
        var name: String
        var kind: String
        var qualifier: String?
        var phrase: String?
        var startYear: Int?
        var startMonth: Int?
        var startDay: Int?
        var startHour: Int?
        var startMinute: Int?
        var startSecond: Int?
        var startMillisecond: Int?
        var startTZ: String?
        var endYear: Int?
        var endMonth: Int?
        var endDay: Int?
        var endHour: Int?
        var endMinute: Int?
        var endSecond: Int?
        var endMillisecond: Int?
        var endTZ: String?
        var want: String
    }

    @Test func summaryMatchesSharedFixtures() throws {
        let fixtures = try Self.loadFixtures()
        #expect(!fixtures.isEmpty)
        for fixture in fixtures {
            var draft = DateValueDraft.empty()
            draft.setKind(fixture.kind)
            draft.qualifier = fixture.qualifier ?? ""
            draft.phrase = fixture.phrase ?? ""
            draft.startYear = fixture.startYear.map(Int32.init)
            draft.startMonth = fixture.startMonth.map(Int32.init)
            draft.startDay = fixture.startDay.map(Int32.init)
            draft.startHour = fixture.startHour.map(Int32.init)
            draft.startMinute = fixture.startMinute.map(Int32.init)
            draft.startSecond = fixture.startSecond.map(Int32.init)
            draft.startMillisecond = fixture.startMillisecond.map(Int32.init)
            draft.startTZ = fixture.startTZ ?? ""
            draft.endYear = fixture.endYear.map(Int32.init)
            draft.endMonth = fixture.endMonth.map(Int32.init)
            draft.endDay = fixture.endDay.map(Int32.init)
            draft.endHour = fixture.endHour.map(Int32.init)
            draft.endMinute = fixture.endMinute.map(Int32.init)
            draft.endSecond = fixture.endSecond.map(Int32.init)
            draft.endMillisecond = fixture.endMillisecond.map(Int32.init)
            draft.endTZ = fixture.endTZ ?? ""
            #expect(
                draft.summary == fixture.want,
                "\(fixture.name): got \(draft.summary.debugDescription) want \(fixture.want.debugDescription)"
            )
        }
    }

    private static func loadFixtures() throws -> [Fixture] {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let root = testsDir
            .deletingLastPathComponent() // macos
            .deletingLastPathComponent() // repo
        let url = root
            .appendingPathComponent("testdata")
            .appendingPathComponent("datevalues")
            .appendingPathComponent("format_summary.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Fixture].self, from: data)
    }
}
