import Foundation
import Testing
@testable import PixNabCore

@Suite struct Release09Tests {
    @Test func testTrackpadSmallEventsDoNotZoomAtEveryEvent() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: 2, precise: true) == 0)
        #expect(accumulator.consume(delta: 2, precise: true) == 0)
        #expect(accumulator.consume(delta: 2, precise: true) == 0)
        #expect(accumulator.consume(delta: 3, precise: true) == 1)
    }

    @Test func testTrackpadAccumulatesIndependentGesturesWithoutDrift() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: 13, precise: true) == 1)
        #expect(accumulator.consume(delta: 5, precise: true) == 1)
        #expect(accumulator.consume(delta: 2, precise: true) == 0)
        accumulator.reset()
        #expect(accumulator.consume(delta: 7, precise: true) == 0)
    }

    @Test func testTrackpadNegativeDirection() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: -18, precise: true) == -2)
        #expect(accumulator.consume(delta: -5, precise: true) == 0)
        #expect(accumulator.consume(delta: -4, precise: true) == -1)
    }

    @Test func testTrackpadIgnoresNonfiniteDeltas() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: Double.nan, precise: true) == 0)
        #expect(accumulator.consume(delta: Double.infinity, precise: true) == 0)
        #expect(accumulator.consume(delta: 9, precise: true) == 1)
    }

    @Test func testScrollSpikeIsCapped() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: 10_000, precise: true) == 4)
        #expect(accumulator.consume(delta: 9, precise: true) == 2)
    }

    @Test func testMouseWheelAlwaysOneStepAndResetsTrackpadRemainder() {
        var accumulator = ScrollStepAccumulator()
        #expect(accumulator.consume(delta: 8, precise: true) == 0)
        #expect(accumulator.consume(delta: 1, precise: false) == 1)
        #expect(accumulator.consume(delta: 1, precise: true) == 0)
        #expect(accumulator.consume(delta: -3, precise: false) == -1)
    }

    @Test func testMixedDPIOriginsAndNegativeVirtualCoordinates() {
        let screens: [(Double, Double, Double, Double, Int, Int)] = [
            (-1920, 0, 1920, 1080, 1920, 1080),
            (0, 0, 1512, 982, 3024, 1964),
            (1512, -420, 1280, 800, 2560, 1600)
        ]
        for (sx, sy, sw, sh, pw, ph) in screens {
            for p in [PixelPoint(x: 0, y: 0),
                      PixelPoint(x: pw / 2, y: ph / 2),
                      PixelPoint(x: pw - 1, y: ph - 1)] {
                guard let screenPoint = PixelGeometry.center(of: p, displayX: sx, displayY: sy,
                    widthPoints: sw, heightPoints: sh, widthPixels: pw, heightPixels: ph) else {
                    Issue.record("valid pixel should map")
                    return
                }
                #expect(PixelGeometry.point(globalX: screenPoint.x,
                    globalY: screenPoint.y, displayX: sx, displayY: sy, widthPoints: sw,
                    heightPoints: sh, widthPixels: pw, heightPixels: ph) == p)
            }
        }
    }

    @Test func testOutOfBoundsPixelRejectedOnDisconnectedGeometry() {
        #expect((PixelGeometry.point(globalX: 200, globalY: 200,
            displayX: 0, displayY: 0, widthPoints: 0, heightPoints: 800,
            widthPixels: 0, heightPixels: 1600)) == nil)
    }

    @Test func testFormattedSessionKeepsOrderAcrossFormats() {
        var session = PickSession()
        session.append(SRGBColor(red8: 255, green8: 0, blue8: 0))
        session.append(SRGBColor(red8: 0, green8: 255, blue8: 0))
        let text = session.formatted(as: .cssHex, options: .init(), separator: .newLine)
        #expect(text == "#ff0000\n#00ff00")
    }

    @Test func testHistoryRepeatedColorDoesNotCreateDuplicatesAtScale() {
        var history = ColorHistory()
        let red = SRGBColor(red8: 255, green8: 0, blue8: 0)
        for _ in 0..<1_000 { history.add(red) }
        #expect(history.items.count == 1)
    }

    @Test func testFormatMenuHasStableUniqueIdentifiers() {
        #expect(ColorOutputFormat.allCases.count == Set(ColorOutputFormat.allCases.map(\.rawValue)).count)
    }
}
