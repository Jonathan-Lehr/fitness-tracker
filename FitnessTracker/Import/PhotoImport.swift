import Foundation
import CoreGraphics
import Vision

enum PhotoImportError: LocalizedError {
    case unreadableImage

    var errorDescription: String? { "That file couldn't be read as an image." }
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

/// One OCR pass over a photo: the recognized text and what the parser made of it.
struct OCRReading {
    var items: [RecognizedText]
    var summary: IFitSummary

    var recognizedFieldCount: Int { IFitSummary.Field.allCases.count - summary.missingFields.count }

    static func read(_ image: CGImage) throws -> OCRReading {
        let items = try TextRecognizer.recognize(image)
        return OCRReading(items: items, summary: IFitSummaryParser.parse(items: items))
    }

    /// Reads the photo as taken and, when the screen is visibly angled, a straightened copy too.
    static func bestReading(of image: CGImage) throws -> OCRReading {
        let original = try read(image)
        let straightened = ScreenStraightener.straightened(image).flatMap { try? read($0) }
        return preferred(original: original, straightened: straightened)
    }

    /// The straightened reading unless it found fewer fields than the original.
    static func preferred(original: OCRReading, straightened: OCRReading?) -> OCRReading {
        guard let straightened, straightened.recognizedFieldCount >= original.recognizedFieldCount else { return original }
        return straightened
    }
}

/// Result of importing a photo: parsed values plus the JPEG to attach.
struct PhotoImportResult {
    var summary: IFitSummary
    var photoJPEG: Data?
    /// Thumbnail framing for `photoJPEG`, or nil if Vision failed (the backfill retries later).
    /// Fractions carry over because the stored JPEG is a uniform downscale of the same upright image.
    var thumbnailAnalysis: ThumbnailFocusAnalysis?

    static func process(imageData: Data) async throws -> PhotoImportResult {
        try await Task.detached(priority: .userInitiated) {
            guard let image = ImageTools.cgImage(from: imageData) else { throw PhotoImportError.unreadableImage }
            let reading = try OCRReading.bestReading(of: image)
            return PhotoImportResult(summary: reading.summary,
                                     photoJPEG: ImageTools.storageJPEG(from: imageData),
                                     thumbnailAnalysis: try? ThumbnailFocusFinder.analyze(image))
        }.value
    }
}
