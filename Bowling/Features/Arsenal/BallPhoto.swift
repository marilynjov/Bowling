import Foundation
import UIKit

/// A picked ball photo made small enough for the list and detail header (spec §7): at most
/// 1024 px on the longest side, never upscaled, JPEG at quality 0.8.
enum BallPhoto {
    static let maxPixels: CGFloat = 1024

    /// Nil when `data` isn't an image.
    static func downscaled(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard width > 0, height > 0 else { return nil }
        let factor = min(1, maxPixels / max(width, height))
        let size = CGSize(width: (width * factor).rounded(), height: (height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.8)
    }
}
