import UIKit
import UniformTypeIdentifiers

/// Share Extension: забирает текст/ссылку и открывает приложение по схеме
/// `muzea://share`, где пользователь выбирает чат.
final class ShareViewController: UIViewController {
    private var didStart = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        extract()
    }

    private func extract() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        }) else {
            finish()
            return
        }

        let type = provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            ? UTType.plainText.identifier
            : UTType.url.identifier

        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
            let text: String?
            if let string = item as? String {
                text = string
            } else if let url = item as? URL {
                text = url.absoluteString
            } else if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            } else {
                text = nil
            }

            DispatchQueue.main.async {
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self?.finish()
                    return
                }
                self?.openHost(text: text)
            }
        }
    }

    private func openHost(text: String) {
        var components = URLComponents(string: "muzea://share")
        components?.queryItems = [
            URLQueryItem(name: "text", value: String(text.prefix(4000)))
        ]
        guard let url = components?.url else {
            finish()
            return
        }
        extensionContext?.open(url) { [weak self] _ in
            self?.finish()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
