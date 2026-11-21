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
        static let avatar: CGFloat = 32
        static let bubbleMaxWidth: CGFloat = 250
        static let mediaMaxWidth: CGFloat = 250
        static let composerMinHeight: CGFloat = 30
        static let composerMaxHeight: CGFloat = 123
        static let iconButton: CGFloat = 44
    }

    /// Цвета повторяют Android-тему: исходящий пузырь — фиолетовый градиент,
    /// входящий — светлая поверхность.
    enum Palette {
        static let outgoingStart = Color(hex: 0x6200EE)
        static let outgoingEnd = Color(hex: 0x7F39FB)
        /// Точные цвета Android: `#EFEFEF` днём и `#2A2A30` ночью.
        static let incomingBubble = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0x2A / 255, green: 0x2A / 255, blue: 0x30 / 255, alpha: 1)
                : UIColor(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255, alpha: 1)
        })
        /// `purple_200` из Android: фон своей реакции.
        static let mineReaction = Color(hex: 0xBB86FC)
        /// `purple_700` из Android: имя автора в цитате ответа.
        static let replyAccent = Color(hex: 0x3700B3)
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
