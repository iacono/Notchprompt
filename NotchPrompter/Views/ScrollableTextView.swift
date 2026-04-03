import SwiftUI
import Cocoa

/// NSScrollView-backed text view with programmatic scroll control.
/// This avoids all SwiftUI layout ambiguity by using AppKit directly.
struct ScrollableTextView: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor
    let lineSpacing: CGFloat
    @ObservedObject var scrollEngine: ScrollEngine

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .none

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 20, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text content and styling
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let cleanText = text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")

        let attributed = NSAttributedString(string: cleanText, attributes: attributes)

        if textView.attributedString() != attributed {
            textView.textStorage?.setAttributedString(attributed)
        }

        // Scroll to the engine's offset position
        let clipView = scrollView.contentView
        let maxY = max(0, (textView.frame.height - clipView.bounds.height))
        let clampedOffset = min(max(0, scrollEngine.scrollOffset), maxY)
        clipView.scroll(to: NSPoint(x: 0, y: clampedOffset))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
    }
}
