import SwiftUI
import UIKit

/// Единые размеры, радиусы и цвета интерфейса. Токены держим в одном месте,
/// чтобы экраны не расходились по случайным числам и правки темы не требовали
/// обхода всех вью.
enum Theme {

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let bubble: CGFloat = 16
        static let media: CGFloat = 12
        static let card: CGFloat = 14
        static let field: CGFloat = 8
    }

    enum Size {
        static let avatar: CGFloat = 28
        static let bubbleMaxWidth: CGFloat = 250
        static let mediaMaxWidth: CGFloat = 250
        static let composerMinHeight: CGFloat = 44
        static let composerMaxHeight: CGFloat = 140
        static let iconButton: CGFloat = 44
    }

    /// Цвета повторяют Android-тему: исходящий пузырь — фиолетовый градиент,
    /// входящий — светлая поверхность.
    enum Palette {
        static let outgoingStart = Color(hex: 0x6200EE)
        static let outgoingEnd = Color(hex: 0x7F39FB)
        static let incomingBubble = Color(.secondarySystemBackground)
        static let selection = Color.accentColor.opacity(0.12)
        static let composerField = Color(.secondarySystemBackground)

        static var outgoingBubble: LinearGradient {
            LinearGradient(
                colors: [outgoingStart, outgoingEnd],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

extension Color {
    /// Цвет из `0xRRGGBB` — так проще сверять с Android `colors.xml`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
