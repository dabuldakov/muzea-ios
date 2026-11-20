import SwiftUI
import UIKit

/// UITextView, который сам сообщает SwiftUI высоту по содержимому.
///
/// Без этого `UIViewRepresentable` внутри flexible frame растягивался до
/// `maxHeight` (поле выглядело высоким даже с одной строкой). Высота считается
/// в `intrinsicContentSize` и пересчитывается при вводе и смене ширины.
final class AutoGrowingTextView: UITextView {
    var minHeight: CGFloat = 36
    var maxHeight: CGFloat = 140

    private var lastWidth: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : max(1, UIScreen.main.bounds.width - 120)
        let fitting = sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        let height = min(maxHeight, max(minHeight, fitting.height))
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - lastWidth) > 0.5 {
            lastWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }
}

/// Многострочное поле ввода с доступом к позиции курсора. Нужен, потому что
/// SwiftUI `TextField` до iOS 18 не отдаёт selection, а подсказки `@` должны
/// работать в любой позиции текста, как `MentionSuggestions` на Android.
struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AutoGrowingTextView {
        let view = AutoGrowingTextView()
        view.delegate = context.coordinator
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 5, left: 4, bottom: 5, right: 4)
        view.textContainer.lineFragmentPadding = 0
        view.autocapitalizationType = .sentences
        view.autocorrectionType = .default
        view.keyboardType = .default
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: AutoGrowingTextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
            let end = NSRange(location: (text as NSString).length, length: 0)
            uiView.selectedRange = end
            uiView.invalidateIntrinsicContentSize()
            DispatchQueue.main.async {
                if self.selection != end { self.selection = end }
            }
            return
        }

        let length = (uiView.text as NSString).length
        let location = min(max(selection.location, 0), length)
        let safe = NSRange(location: location, length: min(max(selection.length, 0), length - location))
        if uiView.selectedRange != safe {
            uiView.selectedRange = safe
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: AutoGrowingTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(
            width: width,
            height: min(uiView.maxHeight, max(uiView.minHeight, fitting.height))
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MentionTextEditor

        init(_ parent: MentionTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selection = textView.selectedRange
            textView.invalidateIntrinsicContentSize()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if parent.selection != textView.selectedRange {
                parent.selection = textView.selectedRange
            }
        }
    }
}
