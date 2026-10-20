import SwiftUI
import UIKit

/// Single-tap recognizers with different touch counts, without a double-tap
/// failure dependency. One finger therefore acts as soon as that finger lifts.
struct ReaderTapGesture: UIGestureRecognizerRepresentable {
    let touches: Int
    let action: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 1
        recognizer.numberOfTouchesRequired = touches
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        action(context.converter.localLocation)
    }
}

extension View {
    func readerTaps(onTap: @escaping (CGPoint) -> Void, onControls: @escaping () -> Void) -> some View {
        gesture(ReaderTapGesture(touches: 1, action: onTap))
            .gesture(ReaderTapGesture(touches: 2, action: { _ in onControls() }))
    }
}
