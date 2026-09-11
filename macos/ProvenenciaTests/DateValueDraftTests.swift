import Foundation
import Testing
@testable import Provenencia

@Suite
struct DateValueDraftTests {
    @Test func summaryPointYearABT() {
        var d = DateValueDraft.empty()
        d.qualifier = "ABT"
        d.startYear = 1890
        #expect(d.summary == "ABT 1890")
        #expect(d.isValid)
    }

    @Test func summaryPointFullDay() {
        var d = DateValueDraft.empty()
        d.startYear = 1985
        d.startMonth = 5
        d.startDay = 14
        #expect(d.summary == "14 May 1985")
        #expect(d.isValid)
    }

    @Test func summaryPointMonth() {
        var d = DateValueDraft.empty()
        d.startYear = 1911
        d.startMonth = 3
        #expect(d.summary == "Mar 1911")
        #expect(d.isValid)
    }

    @Test func summaryRangeYears() {
        var d = DateValueDraft.empty()
        d.setKind("range")
        d.startYear = 1880
        d.endYear = 1885
        #expect(d.summary == "BET 1880 AND 1885")
        #expect(d.isValid)
        #expect(d.endError == nil)
    }

    @Test func summaryPhraseOnly() {
        var d = DateValueDraft.empty()
        d.phrase = "Christmas"
        #expect(d.summary == "Christmas")
        #expect(d.isValid)
    }

    @Test func emptySummaryAndInvalidWithoutPhrase() {
        let d = DateValueDraft.empty()
        #expect(d.summary == "")
        #expect(!d.isValid)
    }

    @Test func rangeEndBeforeStartIsInvalid() {
        var d = DateValueDraft.empty()
        d.setKind("range")
        d.startYear = 1890
        d.endYear = 1880
        #expect(!d.isValid)
        #expect(d.endError != nil)
    }

    @Test func cascadeGapInvalidates() {
        var d = DateValueDraft.empty()
        d.startYear = 1900
        d.startDay = 5
        #expect(!d.isValid)
    }

    @Test func setKindRangeClearsQualifier() {
        var d = DateValueDraft.empty()
        d.qualifier = "ABT"
        d.startYear = 1900
        d.setKind("range")
        #expect(d.qualifier == "")
        d.endYear = 1901
        #expect(d.isValid)
    }

    @Test func toInputMapsPointComponents() {
        var d = DateValueDraft.empty()
        d.qualifier = "BEF"
        d.startYear = 1920
        d.startMonth = 6
        let input = d.toInput()
        #expect(input.kind == "point")
        #expect(input.qualifier == "BEF")
        #expect(input.startYear == 1920)
        #expect(input.startMonth == 6)
        #expect(input.endYear == nil)
    }

    @Test func applyStartCascadeClearsFiner() {
        var d = DateValueDraft.empty()
        d.startYear = 2000
        d.startMonth = 4
        d.startDay = 10
        d.startHour = 8
        d.startMonth = nil
        d.applyStartCascade()
        #expect(d.startDay == nil)
        #expect(d.startHour == nil)
    }

    @Test func dayOutOfRangeShowsFieldError() {
        var d = DateValueDraft.empty()
        d.startYear = 1890
        d.startMonth = 5
        d.startDay = 1890
        #expect(d.isFieldInvalid(.day, start: true))
        #expect(d.fieldError(.day, start: true) != nil)
        #expect(d.cascadeFieldError(start: true) != nil)
        #expect(!d.isValid)
    }

    @Test func hourOutOfRangeShowsFieldError() {
        var d = DateValueDraft.empty()
        d.startYear = 1911
        d.startMonth = 3
        d.startDay = 3
        d.startHour = 30
        #expect(d.isFieldInvalid(.hour, start: true))
        #expect(!d.isValid)
    }
}
