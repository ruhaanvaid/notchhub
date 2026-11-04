import AppKit
import SwiftUI

/// Shared visual constants so every notch view reads as one system.
enum NotchStyle {
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.3)
    static let fill = Color.white.opacity(0.08)
    static let fillStrong = Color.white.opacity(0.14)

    static let titleFont = Font.system(size: 14, weight: .semibold)
    static let bodyFont = Font.system(size: 12, weight: .regular)
    static let captionFont = Font.system(size: 11, weight: .medium)

    static let cornerRadius: CGFloat = 14
}

extension NSImage {
    /// Average colour, used to tint the glow behind album art. Nil for empty images.
    var averageColor: NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard pixel[3] > 0 else { return nil }
        return NSColor(
            red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255, alpha: 1
        )
    }
}
