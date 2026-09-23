import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Crop, rotate, exposure, contrast, warmth. Pure value type so it can cross actor boundaries.
struct ImageAdjustments: Equatable, Sendable {
    /// EV, -2...2
    var exposure: Double = 0
    /// 0.5...1.5, 1 = unchanged
    var contrast: Double = 1
    /// -1...1, 0 = unchanged
    var warmth: Double = 0
    /// Clockwise quarter turns.
    var quarterTurns: Int = 0
    /// Unit rect, origin top-left, in the un-rotated image.
    var crop = CGRect(x: 0, y: 0, width: 1, height: 1)

    var isIdentity: Bool { self == ImageAdjustments() }
    var isCropped: Bool { crop != CGRect(x: 0, y: 0, width: 1, height: 1) || quarterTurns % 4 != 0 }
}

/// Core Image pipeline. Runs off the main thread; CIContext is thread-safe.
enum ImageAdjust {
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    /// Renders the adjusted image. `maxPixel` bounds the longest side for previews.
    static func render(data: Data, adjustments: ImageAdjustments, maxPixel: CGFloat?) -> UIImage? {
        guard var image = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return nil }

        let extent = image.extent
        let crop = adjustments.crop
        let cropRect = CGRect(
            x: extent.minX + crop.minX * extent.width,
            y: extent.minY + (1 - crop.maxY) * extent.height,
            width: crop.width * extent.width,
            height: crop.height * extent.height
        ).integral
        if cropRect.width > 1, cropRect.height > 1 {
            image = image.cropped(to: cropRect)
        }

        let turns = ((adjustments.quarterTurns % 4) + 4) % 4
        if turns != 0 {
            let rotated = image.transformed(by: CGAffineTransform(rotationAngle: -CGFloat(turns) * .pi / 2))
            image = rotated.transformed(by: CGAffineTransform(translationX: -rotated.extent.minX, y: -rotated.extent.minY))
        } else {
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        }

        if adjustments.exposure != 0 {
            let filter = CIFilter.exposureAdjust()
            filter.inputImage = image
            filter.ev = Float(adjustments.exposure)
            image = filter.outputImage ?? image
        }
        if adjustments.contrast != 1 {
            let filter = CIFilter.colorControls()
            filter.inputImage = image
            filter.contrast = Float(adjustments.contrast)
            filter.saturation = 1
            filter.brightness = 0
            image = filter.outputImage ?? image
        }
        if adjustments.warmth != 0 {
            let filter = CIFilter.temperatureAndTint()
            filter.inputImage = image
            filter.neutral = CIVector(x: 6500, y: 0)
            filter.targetNeutral = CIVector(x: 6500 + CGFloat(adjustments.warmth) * 2000, y: 0)
            image = filter.outputImage ?? image
        }

        if let maxPixel {
            let longest = max(image.extent.width, image.extent.height)
            if longest > maxPixel {
                let scale = maxPixel / longest
                image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            }
        }

        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Burns markup into a rendered image.
    static func composite(_ base: UIImage, strokes: [MarkupStroke]) -> UIImage {
        guard !strokes.isEmpty else { return base }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        return renderer.image { rendererContext in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            let cg = rendererContext.cgContext
            for stroke in strokes {
                let (path, width) = MarkupRenderer.path(for: stroke, in: base.size)
                cg.setStrokeColor(UIColor(stroke.color).cgColor)
                cg.setLineWidth(width)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                cg.addPath(path.cgPath)
                cg.strokePath()
            }
        }
    }

    /// HEIF when the encoder is available, JPEG otherwise.
    static func encode(_ image: UIImage) -> Data? {
        if let heif = image.heicData() { return heif }
        return image.jpegData(compressionQuality: 0.92)
    }
}
