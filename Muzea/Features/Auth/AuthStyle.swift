import SwiftUI

enum AuthPalette {
    static let pink = Color(red: 1.00, green: 0.36, blue: 0.54)
    static let purple = Color(red: 0.49, green: 0.30, blue: 1.00)
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let muted = Color(red: 0.43, green: 0.42, blue: 0.49)
    static let cardStroke = Color(red: 0.93, green: 0.91, blue: 0.98)
    static let inputStroke = Color(red: 0.86, green: 0.84, blue: 0.93)
}

/// Белый фон с двумя тонкими розово-фиолетовыми волнами.
struct AuthWaveBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color.white

                wave(size: size, pink: true)
                    .stroke(AuthPalette.pink.opacity(0.20),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .blur(radius: 2)

                wave(size: size, pink: false)
                    .stroke(AuthPalette.purple.opacity(0.20),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .blur(radius: 2)

                wave(size: size, pink: true)
                    .stroke(AuthPalette.pink.opacity(0.82),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                wave(size: size, pink: false)
                    .stroke(AuthPalette.purple.opacity(0.82),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
        .ignoresSafeArea()
    }

    private func wave(size: CGSize, pink: Bool) -> Path {
        let width = size.width
        let height = size.height
        return Path { path in
            if pink {
                path.move(to: CGPoint(x: width * 0.74, y: -height * 0.04))
                path.addCurve(
                    to: CGPoint(x: width * 0.79, y: height * 0.52),
                    control1: CGPoint(x: width * 1.01, y: height * 0.16),
                    control2: CGPoint(x: width * 0.54, y: height * 0.34)
                )
                path.addCurve(
                    to: CGPoint(x: width * 0.83, y: height * 1.04),
                    control1: CGPoint(x: width * 1.02, y: height * 0.69),
                    control2: CGPoint(x: width * 0.55, y: height * 0.84)
                )
            } else {
                path.move(to: CGPoint(x: width * 0.94, y: -height * 0.04))
                path.addCurve(
                    to: CGPoint(x: width * 0.74, y: height * 0.61),
                    control1: CGPoint(x: width * 0.64, y: height * 0.19),
                    control2: CGPoint(x: width * 1.05, y: height * 0.43)
                )
                path.addCurve(
                    to: CGPoint(x: width * 0.72, y: height * 1.04),
                    control1: CGPoint(x: width * 0.47, y: height * 0.76),
                    control2: CGPoint(x: width * 0.93, y: height * 0.89)
                )
            }
        }
    }
}

/// Общий каркас трёх экранов авторизации.
struct AuthScaffold<Content: View, Footer: View>: View {
    private let content: Content
    private let footer: Footer

    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ZStack {
            AuthWaveBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(L10n.appName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AuthPalette.ink)
                            .tracking(-0.5)
                        Text(L10n.loginSubtitle)
                            .font(.subheadline)
                            .foregroundColor(AuthPalette.muted)
                    }
                    .padding(.bottom, 24)

                    content

                    footer
                        .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.light)
    }
}

extension AuthScaffold where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, footer: { EmptyView() })
    }
}

struct AuthCard<Content: View>: View {
    let title: String
    let caption: String?
    private let content: Content

    init(title: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(AuthPalette.ink)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundColor(AuthPalette.muted)
                    .lineSpacing(2)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.top, 20)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AuthPalette.cardStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }
}

private struct AuthInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundColor(AuthPalette.ink)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AuthPalette.inputStroke, lineWidth: 1)
            )
    }
}

extension View {
    func authInput() -> some View {
        modifier(AuthInputModifier())
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                AuthPalette.purple.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AuthLinkButton: View {
    let title: String
    var color: Color = AuthPalette.purple
    var weight: Font.Weight = .medium
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 14, weight: weight))
            .foregroundColor(color)
    }
}

struct AuthLegalLinks: View {
    let open: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            AuthLinkButton(title: L10n.termsLink) { open(Legal.termsURL) }
            AuthLinkButton(title: L10n.policyLink) { open(Legal.policyURL) }
        }
        .font(.caption)
        .fontWeight(.semibold)
    }
}

struct AuthLegalFooter: View {
    let open: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.legalNote)
                .font(.caption2)
                .foregroundColor(AuthPalette.muted)
                .multilineTextAlignment(.center)

            AuthLegalLinks(open: open)
        }
    }
}
