/// Capture policy shared by the native UI and portable validation tests.
/// ScreenCaptureKit provides composited display pixels, not the source document's
/// embedded ICC profile. PixNab deliberately does not invent that provenance.
public enum ColorCaptureContract {
    public static let workingSpace = "sRGB"
    public static let captureSpace = "Display P3"
    public static let captureDynamicRange = "SDR"
    public static let sourceApplicationICCIsKnown = false
    public static let supportsHDRSampling = false
    public static let profileExplanation = "PixNab samples composited Display P3 SDR screen pixels. It stores the display profile name and P3 values when available. The original application's or document's ICC profile is not preserved. The picker does not measure HDR luminance."
    public static let gamutExplanation = "CSS Display P3 uses the captured P3 components. sRGB output clips out-of-gamut colors; HDR capture and measured HDR values are not supported."
}
