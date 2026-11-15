
import Foundation
#if canImport(UIKit)
import UIKit

enum ImageStorage {
    static func jpegData(from original: Data, maxPixel: CGFloat, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: original) else { return nil }
        return jpegData(from: image, maxPixel: maxPixel, quality: quality)
    }

    static func jpegData(from image: UIImage, maxPixel: CGFloat, quality: CGFloat = 0.82) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.jpegData(compressionQuality: quality) }
        let longest = max(size.width, size.height)
        let scale = longest > maxPixel ? maxPixel / longest : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return scaled.jpegData(compressionQuality: quality)
    }
}
#endif
