import AppKit
import CoreFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import PixNabCore

struct SampledPixel {
    let color: SRGBColor
    let patch: CGImage
    let displayProfileName: String?
    let sourceP3: DisplayP3Color?
}

/// Maps an AppKit (bottom-left origin) location into a display's top-left pixel coordinates.
/// This mapping uses the display's reported native dimensions, not a hard-coded Retina scale.
enum DisplayGeometry {
    static func pixel(at point: NSPoint, on screen: NSScreen, pixelWidth: Int, pixelHeight: Int) -> PixelPoint? {
        let bounds = screen.frame
        return PixelGeometry.point(
            globalX: Double(point.x), globalY: Double(point.y),
            displayX: Double(bounds.minX), displayY: Double(bounds.minY),
            widthPoints: Double(bounds.width), heightPoints: Double(bounds.height),
            widthPixels: pixelWidth, heightPixels: pixelHeight)
    }
}

final class FrameRelay: NSObject, SCStreamOutput, SCStreamDelegate {
    var onBuffer: ((CVPixelBuffer, @escaping () -> Void) -> Void)?
    var onFailure: ((Error) -> Void)?
    private let gate = FrameAdmissionGate()
    private let countersLock = NSLock()
    private var rejectedByBackpressure = 0
    var backpressureDrops: Int {
        countersLock.lock()
        defer { countersLock.unlock() }
        return rejectedByBackpressure
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,
                  createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let data = attachments.first,
              let status = data[SCStreamFrameInfo.status] as? Int,
              SCFrameStatus(rawValue: status) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Back-pressure: at most one queued full-resolution frame at a time.
        guard gate.tryBegin() else {
            countersLock.lock()
            rejectedByBackpressure += 1
            countersLock.unlock()
            return
        }
        DispatchQueue.main.async { [weak self, buffer] in
            guard let self else { return }
            // Release admission only when the MainActor consumer has actually
            // sampled/rendered the frame. Releasing on callback scheduling
            // allowed an unbounded queue of UI tasks under load.
            let finish: () -> Void = { [gate = self.gate] in gate.finish() }
            if let action = self.onBuffer { action(buffer, finish) }
            else { finish() }
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onFailure?(error) }
    }
}

/// Captures while picking, never in the background when the picker is idle.
/// The window belonging to our process is excluded from the capture filter.
@MainActor
final class ScreenCaptureEngine {
    private var relay: FrameRelay?
    private var stream: SCStream?
    private var revision: UInt64 = 0
    private(set) var displayID: CGDirectDisplayID?
    private let outputSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let captureSpace = CGColorSpace(name: CGColorSpace.displayP3)!
    private var displayProfileName: String?
    var onFrame: ((CVPixelBuffer) -> Void)?
    var onError: ((String) -> Void)?
    var targetFPS: Int = 30
    var backpressureDrops: Int { relay?.backpressureDrops ?? 0 }

    /// A newer switch or stop invalidates every suspended earlier start.
    func start(on screen: NSScreen, forceRestart: Bool = false) async throws {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw CaptureError.displayUnavailable
        }
        let targetID = CGDirectDisplayID(id.uint32Value)
        if !forceRestart, targetID == displayID, stream != nil { return }

        revision &+= 1
        let request = revision
        let previous = stream
        stream = nil
        relay?.onBuffer = nil
        relay?.onFailure = nil
        relay = nil
        displayID = nil
        displayProfileName = nil
        if let previous { try? await previous.stopCapture() }
        try verify(request)

        let available = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        try verify(request)
        guard let display = available.displays.first(where: { $0.displayID == targetID }) else {
            throw CaptureError.displayUnavailable
        }
        let myBundle = Bundle.main.bundleIdentifier
        let excluded = available.applications.filter { $0.bundleIdentifier == myBundle }
        let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        // An explicit SDR policy prevents platform defaults from silently
        // changing the dynamic range. HDR would require an HDR buffer format,
        // transfer function and separate sampling/formatting pipeline.
        if #available(macOS 15.0, *) { config.captureDynamicRange = .SDR }
        config.showsCursor = false
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(5, min(60, targetFPS))))
        config.queueDepth = 3
        // Request P3 SDR pixels to avoid irreversible sRGB clipping at capture.
        // HDR remains unsupported: this is an 8-bit SDR stream.
        config.colorSpaceName = CGColorSpace.displayP3

        let output = FrameRelay()
        output.onBuffer = { [weak self] buffer, finish in
            Task { @MainActor [weak self] in
                defer { finish() }
                guard let self, self.revision == request else { return }
                self.onFrame?(buffer)
            }
        }
        output.onFailure = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.revision == request else { return }
                self.onError?(error.localizedDescription)
            }
        }
        let next = SCStream(filter: filter, configuration: config, delegate: output)
        try next.addStreamOutput(output, type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "com.pixnab.frames", qos: .userInteractive))
        do {
            try await next.startCapture()
            try verify(request)
        } catch {
            output.onBuffer = nil
            output.onFailure = nil
            try? await next.stopCapture()
            throw error
        }
        relay = output
        stream = next
        displayID = targetID
        displayProfileName = CGDisplayCopyColorSpace(targetID).name as String?
    }

    private func verify(_ request: UInt64) throws {
        if revision != request || Task.isCancelled { throw CancellationError() }
    }

    func stop() async {
        revision &+= 1
        let previous = stream
        stream = nil
        relay?.onBuffer = nil
        relay?.onFailure = nil
        relay = nil
        displayID = nil
        displayProfileName = nil
        if let previous { try? await previous.stopCapture() }
    }

    /// Reads ScreenCaptureKit's Display P3 BGRA8 SDR pixel. Keep the exact encoded
    /// P3 components for wide-gamut CSS export, and convert the selected pixel
    /// with ColorSync/CoreGraphics to the legacy sRGB representation. The patch
    /// retains its P3 tag so macOS can render it on the active display.
    func sample(_ buffer: CVPixelBuffer, at point: PixelPoint, radius: Int) -> SampledPixel? {
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0, width <= Int.max / 4,
              stride >= width * 4, stride <= Int.max / height else { return nil }
        let source = UnsafeRawBufferPointer(start: base, count: stride * height)
        guard let extracted = BGRAExtraction.extract(source: source,
                  width: width, height: height, sourceBytesPerRow: stride,
                  point: point, radius: max(2, min(512, radius))),
              let center = extracted.centerBGRA,
              let provider = CGDataProvider(data: Data(extracted.bytes) as CFData) else { return nil }

        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
                                     CGImageAlphaInfo.premultipliedFirst.rawValue)
        guard let patch = CGImage(width: extracted.side, height: extracted.side,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: extracted.bytesPerRow, space: captureSpace,
                bitmapInfo: bitmapInfo, provider: provider, decode: nil,
                shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let p3 = DisplayP3Color(red: Double(center.2) / 255,
                                green: Double(center.1) / 255,
                                blue: Double(center.0) / 255)
        guard let tagged = CGColor(colorSpace: captureSpace,
                                   components: [CGFloat(p3.red), CGFloat(p3.green), CGFloat(p3.blue), 1]),
              let converted = tagged.converted(to: outputSpace, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else { return nil }
        return SampledPixel(color: SRGBColor(red: Double(components[0]),
                                             green: Double(components[1]),
                                             blue: Double(components[2])), patch: patch,
                            displayProfileName: displayProfileName, sourceP3: p3)
    }

    enum CaptureError: LocalizedError {
        case displayUnavailable
        var errorDescription: String? { "The selected display is unavailable for screen capture." }
    }
}
