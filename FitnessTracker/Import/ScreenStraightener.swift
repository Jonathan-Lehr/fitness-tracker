import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// Corners of a detected screen in Vision's normalized space (fractions, bottom-left origin).
struct ScreenQuadrilateral: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    /// Area as a fraction of the image (shoelace formula).
    var area: Double {
        let points = corners
        let twiceSignedArea = points.indices.reduce(0.0) { sum, index in
            let current = points[index], next = points[(index + 1) % points.count]
            return sum + Double(current.x * next.y - next.x * current.y)
        }
        return abs(twiceSignedArea) / 2
    }

    /// Farthest any corner sits from the matching corner of the quadrilateral's bounding box.
    /// Near zero means the screen is already square to the photo's frame.
    var skew: Double {
        let xs = corners.map(\.x), ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return 0 }
        let boundingCorners = [CGPoint(x: minX, y: maxY), CGPoint(x: maxX, y: maxY),
                               CGPoint(x: maxX, y: minY), CGPoint(x: minX, y: minY)]
        return zip(corners, boundingCorners)
            .map { corner, boundingCorner in Double(hypot(corner.x - boundingCorner.x, corner.y - boundingCorner.y)) }
            .max() ?? 0
    }
}

extension ScreenQuadrilateral {
    init(_ observation: VNRectangleObservation) {
        self.init(topLeft: observation.topLeft, topRight: observation.topRight,
                  bottomRight: observation.bottomRight, bottomLeft: observation.bottomLeft)
    }
}

/// Squares up angled photos of the iFit summary screen, only as input to OCR. The saved and
/// displayed photo is never changed. Synchronous: call it off the main thread.
enum ScreenStraightener {
    /// Vision confidence a screen rectangle needs before the photo is corrected.
    static let minimumConfidence: Float = 0.8
    /// Smallest screen worth correcting, as a fraction of the photo, so a stats card or button
    /// detected inside the screen isn't mistaken for the whole screen.
    static let minimumArea = 0.25
    /// Below this skew the photo is already square enough; correcting would only resample it.
    static let minimumSkew = 0.01

    static func shouldStraighten(_ screen: ScreenQuadrilateral, confidence: Float) -> Bool {
        confidence >= minimumConfidence && screen.area >= minimumArea && screen.skew >= minimumSkew
    }

    /// A perspective-corrected copy of the screen, or nil when no confident, large rectangle is found.
    static func straightened(_ image: CGImage) -> CGImage? {
        guard let observation = try? detectScreen(in: image) else { return nil }
        let screen = ScreenQuadrilateral(observation)
        guard shouldStraighten(screen, confidence: observation.confidence) else { return nil }
        return perspectiveCorrected(image, screen: screen)
    }

    private static func detectScreen(in image: CGImage) throws -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = minimumConfidence
        request.minimumSize = 0.5            // fraction of the photo's shorter side
        request.minimumAspectRatio = 0.3     // shorter side / longer side
        request.maximumAspectRatio = 1
        request.quadratureTolerance = 30     // degrees from square at each corner
        request.maximumObservations = 1
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return request.results?.first
    }

    /// Core Image and Vision both use a bottom-left origin, so normalized corners scale straight to pixels.
    private static func perspectiveCorrected(_ image: CGImage, screen: ScreenQuadrilateral) -> CGImage? {
        let input = CIImage(cgImage: image)
        let size = input.extent.size
        func pixel(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * size.width, y: point.y * size.height) }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = pixel(screen.topLeft)
        filter.topRight = pixel(screen.topRight)
        filter.bottomRight = pixel(screen.bottomRight)
        filter.bottomLeft = pixel(screen.bottomLeft)
        guard let output = filter.outputImage else { return nil }
        return ImageTools.coreImageContext.createCGImage(output, from: output.extent)
    }
}
