import Foundation
import CoreGraphics

/// Builds card thumbnails from a ride's saved (already downscaled) photo.
/// The saved photo is never modified; thumbnails are derived and cached in memory only.
enum ThumbnailCropper {
    /// Fraction of image height kept for the scenic band. iFit summary screens put the scenery
    /// header above the title/stats panel; camera shots of the screen add bezel, so the band
    /// starts a little below the top. Conservative fixed bounds, not content-aware.
    static let bandTop = 0.10
    static let bandBottom = 0.36
    /// Horizontal inset trimming bezel/edge UI on camera shots.
    static let sideInset = 0.06

    /// Crop rect (pixels, top-left origin) for the scenic band, trimmed to `aspect` (width/height),
    /// centered horizontally within the band. Returns nil for degenerate sizes.
    static func cropRect(width: Int, height: Int, aspect: Double) -> CGRect? {
        guard width >= 32, height >= 32, aspect > 0, aspect.isFinite else { return nil }
        let w = Double(width), h = Double(height)
        let bandX = w * sideInset, bandW = w * (1 - 2 * sideInset)
        let bandY = h * bandTop, bandH = h * (bandBottom - bandTop)
        var cropW = bandW, cropH = bandW / aspect
        if cropH > bandH { cropH = bandH; cropW = bandH * aspect }
        let x = bandX + (bandW - cropW) / 2
        let y = bandY + (bandH - cropH) / 2
        return CGRect(x: x, y: y, width: cropW, height: cropH).integral
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
    }

    /// Rejects crops that are nearly black or flat (e.g. dark bezel, blank screen), so the card
    /// falls back to the placeholder. Uses a tiny luminance sample.
    static func isUsable(_ image: CGImage) -> Bool {
        guard let stats = luminanceStats(image) else { return false }
        return stats.mean >= 0.10 && stats.stdDev >= 0.04
    }

    static func luminanceStats(_ image: CGImage, side: Int = 16) -> (mean: Double, stdDev: Double)? {
        var px = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &px, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var values: [Double] = []
        values.reserveCapacity(side * side)
        for i in stride(from: 0, to: px.count, by: 4) {
            values.append((0.2126 * Double(px[i]) + 0.7152 * Double(px[i + 1]) + 0.0722 * Double(px[i + 2])) / 255)
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (mean, variance.squareRoot())
    }

    /// Decodes the saved photo once at reduced size, crops the scenic band and returns it,
    /// or nil if the photo is unreadable or the crop looks unusable.
    static func thumbnail(from data: Data, aspect: Double, maxPixel: Int = 900) -> CGImage? {
        guard let image = ImageTools.cgImage(from: data, maxPixel: maxPixel),
              let rect = cropRect(width: image.width, height: image.height, aspect: aspect),
              let cropped = image.cropping(to: rect),
              isUsable(cropped) else { return nil }
        return cropped
    }
}

/// Bounded in-memory cache of derived thumbnails. Work runs off the main thread; a failed
/// crop is cached too so it isn't retried while scrolling.
actor ThumbnailStore {
    static let shared = ThumbnailStore()

    private final class Entry { let image: CGImage?; init(_ i: CGImage?) { image = i } }
    private let cache: NSCache<NSString, Entry> = {
        let c = NSCache<NSString, Entry>()
        c.countLimit = 300
        return c
    }()

    static func key(id: String, data: Data, aspect: Double) -> String {
        "\(id)|\(data.count)|\(data.hashValue)|\(Int(aspect * 100))"
    }

    func thumbnail(id: String, data: Data, aspect: Double) async -> CGImage? {
        let key = Self.key(id: id, data: data, aspect: aspect) as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        let image = await Task.detached(priority: .utility) {
            ThumbnailCropper.thumbnail(from: data, aspect: aspect)
        }.value
        cache.setObject(Entry(image), forKey: key)
        return image
    }
}
