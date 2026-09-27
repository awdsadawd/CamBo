import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies Core Image filters to enhance lines and contrast for tracing.
public final class ImageFilterService {
    public static let shared = ImageFilterService()

    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 30
    }

    /// Applies the specified filter to an input UIImage.
    public func applyFilter(_ filter: TraceFilter, to image: UIImage) -> UIImage {
        if filter == .original {
            return image
        }

        let cacheKey = "\(image.hashValue)_\(filter.rawValue)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        guard let ciImage = CIImage(image: image) else {
            return image
        }

        var outputCIImage: CIImage?

        switch filter {
        case .original:
            return image

        case .grayscale:
            // Convert to grayscale using ColorControls (saturation = 0)
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 0.0
            filter.contrast = 1.1
            outputCIImage = filter.outputImage

        case .highContrast:
            // High contrast black & white
            let bwFilter = CIFilter.colorControls()
            bwFilter.inputImage = ciImage
            bwFilter.saturation = 0.0
            bwFilter.contrast = 2.4
            bwFilter.brightness = 0.05
            outputCIImage = bwFilter.outputImage

        case .edgeDetection:
            // Outline / Edges using Sobel edge detection
            let edgesFilter = CIFilter.edges()
            edgesFilter.inputImage = ciImage
            edgesFilter.intensity = 4.0

            if let edgeOutput = edgesFilter.outputImage {
                // Invert edges so lines are black on white, or high contrast
                let invertFilter = CIFilter.colorInvert()
                invertFilter.inputImage = edgeOutput
                outputCIImage = invertFilter.outputImage
            }

        case .invert:
            let filter = CIFilter.colorInvert()
            filter.inputImage = ciImage
            outputCIImage = filter.outputImage

        case .lineArt:
            // Comic effect creates distinct outlines and simplified comic shading
            let comicFilter = CIFilter.comicEffect()
            comicFilter.inputImage = ciImage

            if let comicOutput = comicFilter.outputImage {
                let bwFilter = CIFilter.colorControls()
                bwFilter.inputImage = comicOutput
                bwFilter.saturation = 0.0
                bwFilter.contrast = 1.5
                outputCIImage = bwFilter.outputImage
            }
        }

        guard let finalCI = outputCIImage,
              let cgImage = context.createCGImage(finalCI, from: finalCI.extent) else {
            return image
        }

        let result = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        cache.setObject(result, forKey: cacheKey)
        return result
    }

    /// Clear cache when memory warning occurs or new image is picked.
    public func clearCache() {
        cache.removeAllObjects()
    }
}
