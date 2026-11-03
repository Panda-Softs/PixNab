import Foundation

public struct PixelPoint: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
}

public struct ScreenPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Maps between Cocoa screen points (bottom-left origin) and captured physical pixels
/// (top-left origin). The capture buffer dimensions, NOT NSScreen.backingScaleFactor,
/// determine the pixel density; this matters for scaled and mixed-DPI displays.
public enum PixelGeometry {
    public static func point(
        globalX: Double, globalY: Double,
        displayX: Double, displayY: Double,
        widthPoints: Double, heightPoints: Double,
        widthPixels: Int, heightPixels: Int
    ) -> PixelPoint? {
        guard validGeometry(displayX: displayX, displayY: displayY,
                            widthPoints: widthPoints, heightPoints: heightPoints,
                            widthPixels: widthPixels, heightPixels: heightPixels),
              globalX.isFinite, globalY.isFinite else { return nil }
        let x = (globalX - displayX) / widthPoints
        let y = (displayY + heightPoints - globalY) / heightPoints
        guard x >= 0, x < 1, y >= 0, y <= 1 else { return nil }
        return PixelPoint(x: min(widthPixels - 1, max(0, Int(floor(x * Double(widthPixels))))),
                          y: min(heightPixels - 1, max(0, Int(floor(y * Double(heightPixels))))))
    }

    /// Returns the center of a captured pixel in global Cocoa coordinates. This
    /// is the inverse of `point` for every valid physical pixel.
    public static func center(
        of pixel: PixelPoint,
        displayX: Double, displayY: Double,
        widthPoints: Double, heightPoints: Double,
        widthPixels: Int, heightPixels: Int
    ) -> ScreenPoint? {
        guard validGeometry(displayX: displayX, displayY: displayY,
                            widthPoints: widthPoints, heightPoints: heightPoints,
                            widthPixels: widthPixels, heightPixels: heightPixels),
              (0..<widthPixels).contains(pixel.x),
              (0..<heightPixels).contains(pixel.y) else { return nil }
        return ScreenPoint(
            x: displayX + (Double(pixel.x) + 0.5) * widthPoints / Double(widthPixels),
            y: displayY + heightPoints - (Double(pixel.y) + 0.5) * heightPoints / Double(heightPixels)
        )
    }

    private static func validGeometry(
        displayX: Double, displayY: Double,
        widthPoints: Double, heightPoints: Double,
        widthPixels: Int, heightPixels: Int
    ) -> Bool {
        displayX.isFinite && displayY.isFinite &&
        widthPoints.isFinite && heightPoints.isFinite &&
        widthPoints > 0 && heightPoints > 0 && widthPixels > 0 && heightPixels > 0
    }
}

/// Pixel navigation occurs in the source capture buffer, never in logical points.
public enum PixelNavigation {
    public static func moved(_ point: PixelPoint, dx: Int, dy: Int,
                             width: Int, height: Int) -> PixelPoint? {
        guard width > 0, height > 0,
              (0..<width).contains(point.x), (0..<height).contains(point.y) else { return nil }
        return PixelPoint(x: clampedAdd(point.x, dx, max: width - 1),
                          y: clampedAdd(point.y, dy, max: height - 1))
    }

    private static func clampedAdd(_ value: Int, _ offset: Int, max upper: Int) -> Int {
        let (sum, overflow) = value.addingReportingOverflow(offset)
        if overflow { return offset > 0 ? upper : 0 }
        return min(upper, Swift.max(0, sum))
    }
}
