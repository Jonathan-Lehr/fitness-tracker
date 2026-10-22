import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision

enum PhotoImportError: LocalizedError {
    case unreadableImage
    var errorDescription: String? { "That file couldn't be read as an image." }
}

/// Image helpers built on ImageIO so they work the same on iOS and macOS.
enum ImageTools {
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

/// Runs Vision text recognition and returns observations with top-left-origin boxes.
enum TextRecognizer {
    static func recognize(_ image: CGImage) throws -> [RecognizedText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        // Language correction stays off (it "fixes" numbers into words). customWords is
        // mainly used with correction on, but it's harmless and helps unit tokens.
        request.customWords = ["mi", "ft", "cals", "est", "rpm", "avg", "watts", "Incline", "Resistance", "completed"]
        request.revision = VNRecognizeTextRequestRevision3
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        return observations.compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            let b = obs.boundingBox
            return RecognizedText(text: text, box: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        }
    }
}

/// Result of importing a photo: parsed values plus the JPEG to attach.
struct PhotoImportResult {
    var summary: IFitSummary
    var photoJPEG: Data?
    var recognizedLines: [String]

    static func process(imageData: Data) async throws -> PhotoImportResult {
        try await Task.detached(priority: .userInitiated) {
            guard let image = ImageTools.cgImage(from: imageData) else { throw PhotoImportError.unreadableImage }
            let items = try TextRecognizer.recognize(image)
            return PhotoImportResult(summary: IFitSummaryParser.parse(items: items),
                                     photoJPEG: ImageTools.storageJPEG(from: imageData),
                                     recognizedLines: IFitSummaryParser.groupIntoLines(items))
        }.value
    }
}
