import Foundation
import CoreGraphics
import CoreImage

/// Core Image auto-enhance for displayed ride photos: the same on-device exposure, vibrance,
/// shadows/highlights, and red-eye adjustments Photos uses. Non-destructive: the saved photo is
/// never modified, and enhanced images are only cached in memory alongside thumbnails.
/// Synchronous: call it off the main thread.
enum PhotoEnhancer {
    /// Part of the thumbnail cache key, so enhanced output never collides with unenhanced images.
    /// Bump it when the enhancement changes.
    static let cacheKeyComponent = "enhanced-1"

    /// Shared because creating a context is expensive; CIContext is safe to use from multiple threads.
    private static let context = CIContext(options: [.cacheIntermediates: false])

    /// The auto-adjusted image at the same size, or the original when Core Image suggests no
    /// adjustments or rendering fails.
    static func enhanced(_ image: CGImage) -> CGImage {
        let input = CIImage(cgImage: image)
        let filters = input.autoAdjustmentFilters()
        guard !filters.isEmpty else { return image }
        let output = filters.reduce(input) { partial, filter in
            filter.setValue(partial, forKey: kCIInputImageKey)
            return filter.outputImage ?? partial
        }
        return context.createCGImage(output, from: input.extent) ?? image
    }
}
