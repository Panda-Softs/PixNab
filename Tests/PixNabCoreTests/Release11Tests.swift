import Foundation
import Testing
@testable import PixNabCore

@Suite struct Release11Tests {
    @Test func testSourceGamutIsNotClaimedPreserved() {
        #expect(ColorCaptureContract.workingSpace == "sRGB")
        #expect(ColorCaptureContract.profileExplanation.contains("not preserved"))
    }
    @Test func testACOEmptyFileHasHeader() throws {
        #expect(Array(try AdobeColorSwatch.encode([])) == [0,1,0,0])
    }
    @Test func testACORedByteOrderAndChannels() throws {
        let bytes = Array(try AdobeColorSwatch.encode([SRGBColor(red8: 255, green8: 0, blue8: 0)]))
        #expect(bytes == [0,1,0,1, 0,0, 255,255, 0,0, 0,0, 0,0])
    }
    @Test func testACOSeveralSwatchesHavePredictableLengths() throws {
        let colors = [SRGBColor(red8: 1, green8: 2, blue8: 3), SRGBColor(red8: 4, green8: 5, blue8: 6)]
        let bytes = Array(try AdobeColorSwatch.encode(colors))
        #expect(bytes.count == 24)
        #expect(Array(bytes[0..<4]) == [0,1,0,2])
    }
    @Test func testACOIgnoresAlphaWithoutPremultiplying() throws {
        let base = SRGBColor(red8: 60, green8: 120, blue8: 180, alpha: 1)
        let faded = SRGBColor(red8: 60, green8: 120, blue8: 180, alpha: 0.2)
        let baseEncoded = try AdobeColorSwatch.encode([base])
        let fadedEncoded = try AdobeColorSwatch.encode([faded])
        #expect(baseEncoded == fadedEncoded)
    }
    @Test func testACORejectsTooManyColors() {
        let large = Array(repeating: SRGBColor(red8: 0, green8: 0, blue8: 0), count: 65536)
        do {
            _ = try AdobeColorSwatch.encode(large)
            Issue.record("Expected an encoding error for too many colors")
        } catch {
            #expect(error as? AdobeColorSwatch.EncodingError == .tooManyColors)
        }
    }
}

@Suite struct FrameAdmissionGateTests {
    @Test func testGateRejectsWhilePendingAndResumesAfterFinish() {
        let gate = FrameAdmissionGate()
        #expect(gate.tryBegin())
        for _ in 0..<100 { #expect(!(gate.tryBegin())) }
        gate.finish()
        #expect(gate.tryBegin())
        gate.finish()
    }
    @Test func testConcurrentOffersAcceptOnlyOne() {
        let gate = FrameAdmissionGate()
        let lock = NSLock()
        var accepted = 0
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            if gate.tryBegin() {
                lock.lock(); accepted += 1; lock.unlock()
            }
        }
        #expect(accepted == 1)
        gate.finish()
        #expect(gate.tryBegin())
        gate.finish()
    }
}

@Suite struct ColorGamutPolicyTests {
    @Test func testOutOfGamutInputsClipDeterministically() {
        let sample = SRGBColor(red: 1.2, green: -0.5, blue: 0.5)
        #expect(sample.bytes == [255, 0, 128])
        #expect(ColorFormatter.format(sample, as: .cssHex) == "#ff0080")
    }
    @Test func testNonFiniteInputsHaveDefinedFallback() {
        let sample = SRGBColor(red: .nan, green: .infinity, blue: -.infinity, alpha: .nan)
        #expect(sample.rgbaBytes == [0, 0, 0, 0])
    }
}
