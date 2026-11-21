import SwiftUI
import UIKit

/// UITextView с точной высотой по содержимому: одна строка — компактная,
/// дальше растёт до шести строк. SwiftUI получает высоту через колбэк, чтобы
/// поле не растягивалось до `maxHeight` само по себе.
final class AutoGrowingTextView: UITextView {
    var minHeight: CGFloat = 30
    var maxHeight: CGFloat = 123
    var onHeightChange: ((CGFloat) -> Void)?

    private var lastWidth: CGFloat = 0
    private var lastReportedHeight: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight(for: bounds.width))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(bounds.width - lastWidth) > 0.5 {
            lastWidth = bounds.width
            invalidateIntrinsicContentSize()
            notifyHeight()
        }
    }

    func recalculateHeight() {
        invalidateIntrinsicContentSize()
        notifyHeight()
    }

    private func preferredHeight(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return minHeight }
        let fitting = sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        ).height
        return min(maxHeight, max(minHeight, fitting))
    }

    private func notifyHeight() {
        let height = preferredHeight(for: bounds.width)
        guard abs(height - lastReportedHeight) > 0.5 else { return }
        lastReportedHeight = height
        onHeightChange?(height)
    }
}

/// Многострочное поле ввода с доступом к позиции курсора. Нужен, потому что
/// SwiftUI `TextField` до iOS 18 не отдаёт selection, а подсказки `@` должны
/// работать в любой позиции текста, как `MentionSuggestions` на Android.
struct MentionTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AutoGrowingTextView {
        let view = AutoGrowingTextView()
        view.delegate = context.coordinator
        view.font = .systemFont(ofSize: 16)
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        view.textContainer.lineFragmentPadding = 0
        view.autocapitalizationType = .sentences
        view.autocorrectionType = .default
        view.keyboardType = .default
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.onHeightChange = { newHeight in
            DispatchQueue.main.async {
                if abs(height - newHeight) > 0.5 { height = newHeight }
            }
        }
        return view
    }

    func updateUIView(_ uiView: AutoGrowingTextView, context: Context) {
        context.coordinator.parent = self
        uiView.onHeightChange = { newHeight in
            DispatchQueue.main.async {
                if abs(height - newHeight) > 0.5 { height = newHeight }
            }
        }

        if uiView.text != text {
            uiView.text = text
            let end = NSRange(location: (text as NSString).length, length: 0)
            uiView.selectedRange = end
            uiView.recalculateHeight()
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
        uiView.recalculateHeight()
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
            (textView as? AutoGrowingTextView)?.recalculateHeight()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if parent.selection != textView.selectedRange {
                parent.selection = textView.selectedRange
            }
        }
    }
}
