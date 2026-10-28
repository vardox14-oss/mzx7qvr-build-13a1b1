import UIKit

/// Shrink a picked photo so the base64 payload stays well under the server's ~4 MB cap.
func downscale(_ data: Data, maxDimension: CGFloat = 1280, quality: CGFloat = 0.72) -> Data {
    guard let image = UIImage(data: data) else { return data }
    let size = image.size
    let scale = min(1, maxDimension / max(size.width, size.height))
    let target = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
    return rendered.jpegData(compressionQuality: quality) ?? data
}
