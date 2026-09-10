import Foundation
import Testing
@testable import Provenencia

/// `PVList`'s keyboard behaviour lives in pure helpers so it can be tested
/// without mounting a view — see `PVList.swift`.
@Suite
struct PVListSelectionTests {
    @Test func movesDownAndUp() {
        #expect(PVListSelection.moveIndex(0, delta: 1, count: 5) == 1)
        #expect(PVListSelection.moveIndex(3, delta: -1, count: 5) == 2)
    }

    @Test func clampsAtBothEndsRatherThanWrapping() {
        #expect(PVListSelection.moveIndex(4, delta: 1, count: 5) == 4)
        #expect(PVListSelection.moveIndex(0, delta: -1, count: 5) == 0)
    }

    @Test func clampsAPageJumpToTheLastRow() {
        #expect(PVListSelection.moveIndex(2, delta: 10, count: 5) == 4)
        #expect(PVListSelection.moveIndex(8, delta: -10, count: 12) == 0)
    }

    @Test func startsFromTheEdgeTheMoveCameFromWhenNothingIsFocused() {
        #expect(PVListSelection.moveIndex(-1, delta: 1, count: 5) == 0)
        #expect(PVListSelection.moveIndex(-1, delta: -1, count: 5) == 4)
    }

    @Test func reportsNoFocusForAnEmptyList() {
        #expect(PVListSelection.moveIndex(0, delta: 1, count: 0) == -1)
        #expect(PVListSelection.moveIndex(-1, delta: -1, count: 0) == -1)
    }
}

@Suite
struct PVListTypeaheadMatcherTests {
    private let titles = [
        "Alderwick family photograph",
        "Death certificate — Thomas Alderwick",
        "Ipswich district probate index",
        "Parish register — baptisms",
    ]

    @Test func matchesTheFirstRowWithThePrefix() {
        #expect(PVListTypeaheadMatcher.index(in: titles, prefix: "dea") == 1)
        #expect(PVListTypeaheadMatcher.index(in: titles, prefix: "ips") == 2)
    }

    @Test func matchesCaseInsensitively() {
        #expect(PVListTypeaheadMatcher.index(in: titles, prefix: "ALD") == 0)
    }

    @Test func wrapsForwardFromTheGivenIndexSoRepeatedKeysCycle() {
        #expect(PVListTypeaheadMatcher.index(in: titles, prefix: "a", fromIndex: 1) == 0)
    }

    @Test func reportsNoMatchForAnEmptyPrefixOrNoRows() {
        #expect(PVListTypeaheadMatcher.index(in: titles, prefix: "") == -1)
        #expect(PVListTypeaheadMatcher.index(in: [], prefix: "a") == -1)
    }

    @Test func accumulatesKeystrokesWithinTheResetWindow() {
        var matcher = PVListTypeaheadMatcher()
        let start = Date()
        #expect(matcher.append("p", now: start) == "p")
        #expect(matcher.append("a", now: start.addingTimeInterval(0.2)) == "pa")
    }

    @Test func startsOverAfterThePause() {
        var matcher = PVListTypeaheadMatcher()
        let start = Date()
        _ = matcher.append("p", now: start)
        let afterPause = start.addingTimeInterval(PVListTypeaheadMatcher.resetInterval + 0.01)
        #expect(matcher.append("a", now: afterPause) == "a")
    }

    @Test func resetDropsTheBuffer() {
        var matcher = PVListTypeaheadMatcher()
        _ = matcher.append("p")
        matcher.reset()
        #expect(matcher.append("a") == "a")
    }
}
