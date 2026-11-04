import SwiftUI

/// The notch silhouette: flat top edge with small concave flares into the screen edge,
/// straight sides, and rounded bottom corners. Both radii animate.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let bodyWidth = rect.width - top * 2
        let bottom = max(0, min(bottomRadius, bodyWidth / 2, rect.height - top))

        let left = rect.minX + top
        let right = rect.maxX - top

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top-left flare (concave).
        path.addQuadCurve(
            to: CGPoint(x: left, y: rect.minY + top),
            control: CGPoint(x: left, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: left, y: rect.maxY - bottom))
        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: left + bottom, y: rect.maxY),
            control: CGPoint(x: left, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right - bottom, y: rect.maxY))
        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: right, y: rect.maxY - bottom),
            control: CGPoint(x: right, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: right, y: rect.minY + top))
        // Top-right flare (concave).
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: right, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
