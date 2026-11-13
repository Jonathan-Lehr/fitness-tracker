import Foundation
import CoreGraphics

/// Builds card thumbnails from a ride's saved (already downscaled) photo.
/// The saved photo is never modified; thumbnails are derived and cached in memory only.
enum ThumbnailCropper {
    /// Source band (fractions of image size). iFit summary screens put the scenery/rider header
    /// above the title and stats panel, with "Nice job!" text on the left, so the rider usually
    /// sits right of center. The band starts near the top so heads aren't cut; camera shots may
    /// show a sliver of bezel at the top instead.
    static let bandTop = 0.05
    static let bandBottom = 0.40
    /// Horizontal inset trimming bezel/edge UI on camera shots.
    static let sideInset = 0.06
    /// Horizontal center of the crop when no focus is stored and the band is wider than the card aspect.
    static let centerX = 0.62

    /// The scenic band as fractions of the image, top-left origin. Crops stay inside it, and
    /// `ThumbnailFocusFinder` analyzes only this area.
    static let band = CGRect(x: sideInset, y: bandTop, width: 1 - 2 * sideInset, height: bandBottom - bandTop)

    /// Crop rect (pixels, top-left origin) at `aspect` (width/height) inside the scenic band, as large
    /// as the band allows. With a stored `focus` (fractions, top-left origin) the crop centers on it;
    /// otherwise it uses the fixed framing: anchored to the band top and centered at `centerX`.
    /// Either way it is clamped inside the band. Returns nil for degenerate sizes.
    static func cropRect(width: Int, height: Int, aspect: Double, focus: CGRect? = nil) -> CGRect? {
        guard width >= 32, height >= 32, aspect > 0, aspect.isFinite else { return nil }
        let imageBounds = CGRect(x: 0, y: 0, width: width, height: height)
        let bandPixels = pixelRect(band, in: imageBounds)
        let size = largestSize(aspect: aspect, fitting: bandPixels.size)
        let focusPixels = focus.map { pixelRect($0, in: imageBounds) }
        let cropCenter = focusPixels.map { CGPoint(x: $0.midX, y: $0.midY) }
            ?? CGPoint(x: imageBounds.width * centerX, y: bandPixels.minY + size.height / 2)
        return rect(size: size, centeredOn: cropCenter, clampedInside: bandPixels).integral
            .intersection(imageBounds)
    }

    /// Largest size with `aspect` (width/height) that fits inside `bounds`.
    static func largestSize(aspect: Double, fitting bounds: CGSize) -> CGSize {
        let widthLimited = CGSize(width: bounds.width, height: bounds.width / aspect)
        guard widthLimited.height > bounds.height else { return widthLimited }
        return CGSize(width: bounds.height * aspect, height: bounds.height)
    }

    /// A rect of `size` centered on `center` as closely as possible while staying inside `bounds`.
    /// `size` must fit inside `bounds`.
    static func rect(size: CGSize, centeredOn center: CGPoint, clampedInside bounds: CGRect) -> CGRect {
        let x = min(max(center.x - size.width / 2, bounds.minX), bounds.maxX - size.width)
        let y = min(max(center.y - size.height / 2, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// `fraction` (fractions of `bounds`, top-left origin) in the pixel space of `bounds`.
    static func pixelRect(_ fraction: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX + fraction.minX * bounds.width, y: bounds.minY + fraction.minY * bounds.height,
               width: fraction.width * bounds.width, height: fraction.height * bounds.height)
    }

    /// Rejects crops that are nearly black or flat (e.g. dark bezel, blank screen), so the card
    /// falls back to the placeholder. Uses a tiny luminance sample.
    static func isUsable(_ image: CGImage) -> Bool {
        guard let stats = luminanceStats(image) else { return false }
        return stats.mean >= 0.10 && stats.stdDev >= 0.04
    }

    static func luminanceStats(_ image: CGImage, side: Int = 16) -> (mean: Double, stdDev: Double)? {
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var values: [Double] = []
        values.reserveCapacity(side * side)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            values.append((0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])) / 255)
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (mean, variance.squareRoot())
    }

    /// Decodes the saved photo once at reduced size, crops the scenic band (around `focus` when
    /// one is stored) and returns it, or nil if the photo is unreadable or the crop looks unusable.
    static func thumbnail(from data: Data, aspect: Double, focus: CGRect? = nil, maxPixel: Int = 900) -> CGImage? {
        guard let image = ImageTools.cgImage(from: data, maxPixel: maxPixel),
              let rect = cropRect(width: image.width, height: image.height, aspect: aspect, focus: focus),
              let cropped = image.cropping(to: rect),
              isUsable(cropped) else { return nil }
        return cropped
    }
}

/// Bounded in-memory cache of derived thumbnails. Work runs off the main thread; a failed
/// crop is cached too so it isn't retried while scrolling.
actor ThumbnailStore {
    static let shared = ThumbnailStore()

    private final class Entry {
        let image: CGImage?
        init(_ image: CGImage?) { self.image = image }
    }
    private let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 300
        return cache
    }()

    /// Includes the focus so a ride re-crops once the backfill (or a new photo) changes it.
    static func key(id: String, data: Data, aspect: Double, focus: CGRect? = nil) -> String {
        "\(id)|\(data.count)|\(data.hashValue)|\(Int(aspect * 100))|\(focusKey(focus))"
    }

    /// Focus rounded to 0.1% of the image, or "band" for the fixed framing.
    private static func focusKey(_ focus: CGRect?) -> String {
        guard let focus else { return "band" }
        return [focus.minX, focus.minY, focus.width, focus.height]
            .map { String(Int(($0 * 1000).rounded())) }
            .joined(separator: ",")
    }

    func thumbnail(id: String, data: Data, aspect: Double, focus: CGRect? = nil) async -> CGImage? {
        let key = Self.key(id: id, data: data, aspect: aspect, focus: focus) as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        let image = await Task.detached(priority: .utility) {
            ThumbnailCropper.thumbnail(from: data, aspect: aspect, focus: focus)
        }.value
        cache.setObject(Entry(image), forKey: key)
        return image
    }
}
