import SwiftUI

struct PetResizeHandle: View {
    let scale: CGFloat
    let onScaleChanged: (CGFloat) -> Void
    let onScaleEnded: () -> Void
    @State private var startingScale: CGFloat?

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 27, height: 27)
            .background(.black.opacity(0.78), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if startingScale == nil { startingScale = scale }
                        let distance = (value.translation.width - value.translation.height) / 220
                        onScaleChanged((startingScale ?? scale) + distance)
                    }
                    .onEnded { _ in
                        startingScale = nil
                        onScaleEnded()
                    }
            )
            .accessibilityLabel("调整小猫大小")
    }
}
