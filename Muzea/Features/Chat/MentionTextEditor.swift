import SwiftUI
import UIKit

/// Многострочное поле ввода с доступом к позиции курсора. Нужен, потому что
/// SwiftUI `TextField` до iOS 18 не отдаёт selection, а подсказки `@` должны
/// работать в любой позиции текста, как `MentionSuggestions` на Android.
struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.textContainer.lineFragmentPadding = 0
        view.autocapitalizationType = .sentences
        view.autocorrectionType = .default
        view.keyboardType = .default
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
            let end = NSRange(location: (text as NSString).length, length: 0)
            uiView.selectedRange = end
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
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: min(140, max(44, fitting.height)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MentionTextEditor

        init(_ parent: MentionTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.selection = textView.selectedRange
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if parent.selection != textView.selectedRange {
                parent.selection = textView.selectedRange
            }
        }
    }
}
