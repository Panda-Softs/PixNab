import Foundation

/// Pure, testable cache key for screen sampling. The frame revision changes
/// when a new frame arrives; display changes and preference changes invalidate
/// cached results without depending on a fixed timer frequency.
public struct MagnifierRenderKey: Equatable, Sendable {
    public let frameRevision: UInt64
    public let pixel: PixelPoint
    public let radius: Int
    public let zoom: Int
    public let precise: Bool
    public let format: ColorOutputFormat
    public let showsLabel: Bool
    public let sessionCount: Int

    public init(frameRevision: UInt64, pixel: PixelPoint, radius: Int, zoom: Int,
                precise: Bool, format: ColorOutputFormat, showsLabel: Bool, sessionCount: Int) {
        self.frameRevision = frameRevision
        self.pixel = pixel
        self.radius = radius
        self.zoom = zoom
        self.precise = precise
        self.format = format
        self.showsLabel = showsLabel
        self.sessionCount = sessionCount
    }
}
