import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreImage

/// Image helpers built on ImageIO so they work the same on iOS and macOS.
enum ImageTools {
    /// Shared because creating a context is expensive; CIContext is safe to use from multiple threads.
    static let coreImageContext = CIContext(options: [.cacheIntermediates: false])

    /// Decodes image data into an upright CGImage no larger than `maxPixel` on its long side.
    static func cgImage(from data: Data, maxPixel: Int = 2400) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    /// Downscaled JPEG for storage in Workout.photoData.
    static func storageJPEG(from data: Data, maxPixel: Int = 1600, quality: Double = 0.7) -> Data? {
        guard let image = cgImage(from: data, maxPixel: maxPixel) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
