import Foundation
import Testing
@testable import Provenencia

@Suite
struct TrafficLightsTests {
    @Test func flippedSuperviewMeasuresFromTop() {
        let originY = TrafficLights.verticalOrigin(
            isFlipped: true,
            superviewHeight: 100,
            buttonHeight: 14,
            targetCenterFromTop: 26
        )
        let expected: CGFloat = 19
        #expect(originY == expected)
    }

    @Test func nonFlippedSuperviewMeasuresFromBottom() {
        let originY = TrafficLights.verticalOrigin(
            isFlipped: false,
            superviewHeight: 52,
            buttonHeight: 14,
            targetCenterFromTop: 26
        )
        let expected: CGFloat = 19
        #expect(originY == expected)
    }

    @Test func nonFlippedSuperviewHeightChangesOrigin() {
        let shorter = TrafficLights.verticalOrigin(isFlipped: false, superviewHeight: 52, buttonHeight: 14, targetCenterFromTop: 26)
        let taller = TrafficLights.verticalOrigin(isFlipped: false, superviewHeight: 200, buttonHeight: 14, targetCenterFromTop: 26)
        let difference = taller - shorter
        let expected: CGFloat = 148
        #expect(difference == expected)
    }

    @Test func flippedSuperviewIgnoresSuperviewHeight() {
        let shorter = TrafficLights.verticalOrigin(isFlipped: true, superviewHeight: 52, buttonHeight: 14, targetCenterFromTop: 26)
        let taller = TrafficLights.verticalOrigin(isFlipped: true, superviewHeight: 200, buttonHeight: 14, targetCenterFromTop: 26)
        #expect(shorter == taller)
    }

    @Test func defaultTargetMatchesWorkspaceChrome() {
        let originY = TrafficLights.verticalOrigin(isFlipped: true, superviewHeight: 100, buttonHeight: 14)
        let expected = TrafficLights.verticalCenterFromTop - 7
        #expect(originY == expected)
    }
}
