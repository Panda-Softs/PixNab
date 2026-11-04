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

    /// Place a small independent lens window in the virtual desktop.
    /// Unlike frame(center:diameter:viewport:), this must NOT clamp to one
    /// monitor: such clamping makes the lens jump when crossing the seam.
    /// Keeping the entire circle inside the union bounds also prevents it
    /// from disappearing off the *outside* edge of the desktop.
    public static func floatingFrame(center: ScreenPoint, diameter: Double,
                                     displays: [LensViewport]) -> LensViewport? {
        guard !displays.isEmpty,
              displays.allSatisfy({ $0.x.isFinite && $0.y.isFinite &&
                                   $0.width.isFinite && $0.height.isFinite &&
                                   $0.width > 0 && $0.height > 0 }) else { return nil }
        let minX = displays.map(\.x).min()!
        let minY = displays.map(\.y).min()!
        let maxX = displays.map { $0.x + $0.width }.max()!
        let maxY = displays.map { $0.y + $0.height }.max()!
        guard maxX.isFinite, maxY.isFinite else { return nil }
        return frame(center: center, diameter: diameter,
                     viewport: LensViewport(x: minX, y: minY,
                                            width: maxX - minX, height: maxY - minY))
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
