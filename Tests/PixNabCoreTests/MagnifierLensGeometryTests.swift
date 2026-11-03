import Foundation
import Testing
@testable import PixNabCore

@Suite struct MagnifierLensGeometryTests {
    @Test func testLensIsSquareAndReachesBottomOfCurrentDisplay() throws {
        let screen = LensViewport(x: -1600, y: -900, width: 1600, height: 900)
        let lens = try #require(MagnifierLensGeometry.frame(
            center: ScreenPoint(x: -800, y: -900), diameter: 320, viewport: screen))
        #expect(lens.y == screen.y)
        #expect(lens.width == lens.height)
        #expect(lens.height == 323)
        #expect(lens.x == -961.5)
    }

    @Test func testClampsToEveryEdgeWithoutCaptionSpace() throws {
        for size in [220.0, 320.0, 490.0] {
            let screen = LensViewport(x: 1800, y: 400, width: 1280, height: 800)
            for center in [ScreenPoint(x: 1800, y: 400),
                           ScreenPoint(x: 3080, y: 1200),
                           ScreenPoint(x: 1800, y: 1200),
                           ScreenPoint(x: 3080, y: 400)] {
                let frame = try #require(MagnifierLensGeometry.frame(
                    center: center, diameter: size, viewport: screen))
                #expect(frame.width == size + 3)
                #expect(frame.height == size + 3)
                #expect(frame.x >= screen.x)
                #expect(frame.y >= screen.y)
                #expect(frame.x + frame.width <= screen.x + screen.width)
                #expect(frame.y + frame.height <= screen.y + screen.height)
            }
        }
    }

    @Test func testCaptionRectangleIsWithinCircleAndBelowCrosshair() throws {
        for diameter in [220.0, 300.0, 490.0] {
            let label = try #require(MagnifierLensGeometry.labelFrame(diameter: diameter))
            let center = diameter / 2 + MagnifierLensGeometry.borderInset
            // Corners of the caption must fit within the circular clipping path.
            for x in [label.x, label.x + label.width] {
                for y in [label.y, label.y + label.height] {
                    #expect(pow(x - center, 2) + pow(y - center, 2) < pow(diameter / 2, 2))
                }
            }
            #expect(label.y + label.height < center - 5)
        }
    }

    @Test func testInvalidGeometryDoesNotCreateAFrame() {
        let screen = LensViewport(x: 0, y: 0, width: 800, height: 600)
        #expect((MagnifierLensGeometry.frame(
            center: ScreenPoint(x: 0, y: 0), diameter: .nan, viewport: screen)) == nil)
        #expect((MagnifierLensGeometry.frame(
            center: ScreenPoint(x: 0, y: 0), diameter: -1, viewport: screen)) == nil)
        #expect((MagnifierLensGeometry.frame(
            center: ScreenPoint(x: 0, y: 0), diameter: 320,
            viewport: LensViewport(x: 0, y: 0, width: 0, height: 600))) == nil)
        #expect((MagnifierLensGeometry.labelFrame(diameter: .infinity)) == nil)
    }
}
