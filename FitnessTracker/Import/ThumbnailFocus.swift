import Foundation
import CoreGraphics
import Vision

/// Result of analyzing a ride photo for thumbnail framing. `focus` is the region worth showing,
/// as fractions of the image size with a top-left origin, or nil when nothing stood out. Either
/// way the analysis is done, so it isn't repeated.
struct ThumbnailFocusAnalysis: Equatable, Sendable {
    var focus: CGRect?
}

/// Regions Vision found in the analyzed band, still in Vision's normalized, bottom-left-origin space.
struct ThumbnailFocusCandidates: Equatable {
    var humans: [CGRect] = []
    var faces: [CGRect] = []
    var salientObjects: [CGRect] = []

    /// The rider is usually the subject, so people win. Attention saliency is the fallback because
    /// it can latch onto the "Nice job!" header text instead of the scenery.
    var preferredRegion: CGRect? {
        [humans, faces, salientObjects].lazy.compactMap(Self.union).first
    }

    private static func union(_ rects: [CGRect]) -> CGRect? {
        rects.filter { !$0.isEmpty }.reduce(nil) { partial, rect in partial?.union(rect) ?? rect }
    }
}

/// Finds the part of a ride photo that thumbnails should frame, using on-device Vision.
/// Synchronous and CPU/Neural Engine heavy: call it off the main thread.
enum ThumbnailFocusFinder {
    /// Stored on `Workout` with each result. Bump it when the analysis changes enough that the
    /// backfill should recompute existing rides.
    static let analysisVersion = 1

    /// Long-side size the saved photo is decoded at for analysis; Vision downsamples further anyway.
    static let analysisPixelSize = 900

    private static let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Decodes a saved photo and analyzes it. Returns nil only when Vision fails, so the caller can
    /// retry later; an unreadable photo counts as analyzed with no focus.
    static func analyze(photoData: Data) -> ThumbnailFocusAnalysis? {
        guard let image = ImageTools.cgImage(from: photoData, maxPixel: analysisPixelSize) else {
            return ThumbnailFocusAnalysis(focus: nil)
        }
        return try? analyze(image)
    }

    /// Analyzes only the scenic band `ThumbnailCropper` crops from. On iFit summary screens the
    /// stats panel below it is mostly text, which would otherwise attract saliency.
    static func analyze(_ image: CGImage) throws -> ThumbnailFocusAnalysis {
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let bandPixels = ThumbnailCropper.pixelRect(ThumbnailCropper.band, in: imageBounds)
            .integral.intersection(imageBounds)
        guard !bandPixels.isEmpty, let bandImage = image.cropping(to: bandPixels) else {
            return ThumbnailFocusAnalysis(focus: nil)
        }
        let candidates = try candidates(in: bandImage)
        let analyzedRegion = normalizedRect(bandPixels, in: imageBounds)
        let focus = candidates.preferredRegion.flatMap { imageRect(fromVision: $0, within: analyzedRegion) }
        return ThumbnailFocusAnalysis(focus: focus)
    }

    /// Runs face, human, and attention-saliency requests in one pass over `image`.
    static func candidates(in image: CGImage) throws -> ThumbnailFocusCandidates {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([faceRequest, humanRequest, saliencyRequest])
        return ThumbnailFocusCandidates(
            humans: humanRequest.results?.map(\.boundingBox) ?? [],
            faces: faceRequest.results?.map(\.boundingBox) ?? [],
            salientObjects: saliencyRequest.results?.first?.salientObjects?.map(\.boundingBox) ?? [])
    }

    /// Converts a Vision bounding box (normalized to the analyzed image, bottom-left origin) into
    /// fractions of the full photo with a top-left origin. `region` is where the analyzed image sits
    /// in the full photo, also as top-left-origin fractions. Returns nil for boxes outside the image.
    static func imageRect(fromVision box: CGRect, within region: CGRect) -> CGRect? {
        let clamped = box.intersection(unitRect)
        guard !clamped.isNull, !clamped.isEmpty else { return nil }
        let topLeftOrigin = CGRect(x: clamped.minX, y: 1 - clamped.maxY, width: clamped.width, height: clamped.height)
        return CGRect(x: region.minX + topLeftOrigin.minX * region.width,
                      y: region.minY + topLeftOrigin.minY * region.height,
                      width: topLeftOrigin.width * region.width,
                      height: topLeftOrigin.height * region.height)
    }

    /// `rect` (pixels) as fractions of `bounds`.
    static func normalizedRect(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(x: (rect.minX - bounds.minX) / bounds.width, y: (rect.minY - bounds.minY) / bounds.height,
               width: rect.width / bounds.width, height: rect.height / bounds.height)
    }

    /// True when `rect` is a usable normalized region: finite, non-empty, and inside the unit square
    /// (with a little slack for rounding). Guards against bad values arriving through sync or backups.
    static func isNormalized(_ rect: CGRect) -> Bool {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
        guard values.allSatisfy(\.isFinite), rect.width > 0, rect.height > 0 else { return false }
        return unitRect.insetBy(dx: -0.01, dy: -0.01).contains(rect)
    }
}
