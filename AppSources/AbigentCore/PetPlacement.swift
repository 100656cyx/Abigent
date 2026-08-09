import CoreGraphics
import Foundation

public struct PetPlacement: Codable, Sendable, Equatable {
    public static let minimumScale: CGFloat = 0.5
    public static let maximumScale: CGFloat = 1.5
    public static let defaultScale: CGFloat = 1.0

    public var scale: CGFloat
    public var origin: CGPoint

    public init(scale: CGFloat = defaultScale, origin: CGPoint = .zero) {
        self.scale = scale
        self.origin = origin
    }

    public var normalizedScale: CGFloat {
        min(max(scale, Self.minimumScale), Self.maximumScale)
    }

    public func clamped(to visibleFrame: CGRect, petSize: CGSize) -> PetPlacement {
        let scale = normalizedScale
        let width = min(petSize.width * scale, visibleFrame.width)
        let height = min(petSize.height * scale, visibleFrame.height)
        let maximumX = visibleFrame.maxX - width
        let maximumY = visibleFrame.maxY - height
        return PetPlacement(
            scale: scale,
            origin: CGPoint(
                x: min(max(origin.x, visibleFrame.minX), maximumX),
                y: min(max(origin.y, visibleFrame.minY), maximumY)
            )
        )
    }
}
