import Foundation

/// Geometry shared by the magnifier renderer and its placement logic.
/// Coordinates are in global macOS points (origin at bottom-left).
public struct LensViewport: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum MagnifierLensGeometry {
    /// Stroke inset; it is the *only* area outside the circular image.
    public static let borderInset = 1.5

    /// Return the lens view's outer frame, constrained to the current display.
    /// The view is square. No space is reserved for a caption below the circle.
    public static func frame(center: ScreenPoint, diameter: Double,
                             viewport: LensViewport) -> LensViewport? {
        guard center.x.isFinite, center.y.isFinite, diameter.isFinite,
              diameter > 0, viewport.x.isFinite, viewport.y.isFinite,
              viewport.width.isFinite, viewport.height.isFinite,
              viewport.width > 0, viewport.height > 0 else { return nil }
        let side = diameter + 2 * borderInset
        guard side.isFinite else { return nil }
        let maxX = viewport.x + max(0, viewport.width - side)
        let maxY = viewport.y + max(0, viewport.height - side)
        return LensViewport(x: min(max(viewport.x, center.x - side / 2), maxX),
                            y: min(max(viewport.y, center.y - side / 2), maxY),
                            width: side, height: side)
    }

    /// Local drawing coordinates for a two-line caption inside the lower part
    /// of the circle. The bounding rectangle does not touch the center crosshair.
    public static func labelFrame(diameter: Double) -> LensViewport? {
        guard diameter.isFinite, diameter >= 100 else { return nil }
        let width = diameter * 0.62
        let side = diameter + 2 * borderInset
        return LensViewport(x: (side - width) / 2,
                            y: borderInset + diameter * 0.16,
                            width: width, height: 40)
    }
}
