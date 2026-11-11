import XCTest
import CoreGraphics
@testable import FitnessTracker

final class PhotoEnhancerTests: XCTestCase {
    private func gradient(width: Int, height: Int, brightness: Double) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let value = UInt8(min(255, Double((x * 3 + y * 5) % 256) * brightness))
                let i = (y * width + x) * 4
                pixels[i] = value; pixels[i + 1] = UInt8(Double(value) * 0.8); pixels[i + 2] = UInt8(Double(value) * 0.6)
            }
        }
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    func testEnhancementKeepsSize() {
        let image = gradient(width: 320, height: 160, brightness: 0.4)
        let enhanced = PhotoEnhancer.enhanced(image)
        XCTAssertEqual(enhanced.width, 320)
        XCTAssertEqual(enhanced.height, 160)
    }

    func testThumbnailCacheKeyMarksEnhancedOutput() {
        XCTAssertTrue(ThumbnailStore.key(id: "a", data: Data([1]), aspect: 2).hasSuffix(PhotoEnhancer.cacheKeyComponent))
    }
}
