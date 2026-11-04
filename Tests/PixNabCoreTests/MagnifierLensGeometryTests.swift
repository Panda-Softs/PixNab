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

    @Test func testFloatingLensCrossesHorizontalSeamWithoutSnapping() throws {
        // macOS main monitor at x = 0, external monitor to the right.
        // Clamping to either display would cause a ~160-point jump.
        let displays = [LensViewport(x: 0, y: 0, width: 1512, height: 982),
                        LensViewport(x: 1512, y: -100, width: 1920, height: 1080)]
        let left = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 1511, y: 450), diameter: 320, displays: displays))
        let right = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 1513, y: 450), diameter: 320, displays: displays))
        #expect(abs((right.x - left.x) - 2) < 0.001)
        #expect(left.y == right.y)
        #expect(left.x < 1512 && left.x + left.width > 1512)
        #expect(right.x < 1512 && right.x + right.width > 1512)
    }

    @Test func testFloatingLensCrossesLeftOfPrimaryAndVerticalSeam() throws {
        let left = LensViewport(x: -1920, y: 0, width: 1920, height: 1080)
        let main = LensViewport(x: 0, y: 0, width: 1512, height: 982)
        let a = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: -1, y: 550), diameter: 320, displays: [left, main]))
        let b = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 1, y: 550), diameter: 320, displays: [left, main]))
        #expect(abs(b.x - a.x - 2) < 0.001)
        let above = LensViewport(x: 0, y: 982, width: 1512, height: 800)
        let before = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 640, y: 981), diameter: 320, displays: [main, above]))
        let after = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 640, y: 983), diameter: 320, displays: [main, above]))
        #expect(abs(after.y - before.y - 2) < 0.001)
    }

    @Test func testFloatingLensOuterEdgeAndInvalidDisplayGeometry() throws {
        let displays = [LensViewport(x: 0, y: 0, width: 1512, height: 982),
                        LensViewport(x: 1512, y: 0, width: 1920, height: 1080)]
        let outer = try #require(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 3431, y: 1079), diameter: 320, displays: displays))
        #expect(outer.x + outer.width <= 3432)
        #expect(outer.y + outer.height <= 1080)
        #expect(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 10, y: 10), diameter: 320, displays: []) == nil)
        #expect(MagnifierLensGeometry.floatingFrame(
            center: ScreenPoint(x: 10, y: 10), diameter: 320,
            displays: [LensViewport(x: 0, y: 0, width: .nan, height: 900)]) == nil)
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
