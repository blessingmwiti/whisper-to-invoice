import SwiftUI

/// Renders the small Markdown subset the app's legal texts use: `**bold**`, `[links](url)` and
/// `- ` bullet lines (Android: `MarkdownText`). Links are only opened when they use https or
/// mailto.
struct MarkdownText: View {
    let text: String
    var small = true
    var color: Color = AppPalette.onSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Color.clear.frame(height: 4)
                } else if let bullet = bulletContent(of: line) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").appText(small ? .bodyMedium : .bodyLarge)
                        Text(attributed(bullet)).appText(small ? .bodyMedium : .bodyLarge)
                    }
                } else {
                    Text(attributed(line)).appText(small ? .bodyMedium : .bodyLarge)
                }
            }
        }
        .foregroundStyle(color)
        .tint(AppPalette.link)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            Self.isSafeToOpen(url) ? .systemAction : .discarded
        })
    }

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    private func bulletContent(of line: String) -> String? {
        line.hasPrefix("- ") ? String(line.dropFirst(2)) : nil
    }

    private func attributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }

    static func isSafeToOpen(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "mailto"
    }
}

/// A tappable link row (Android: `ClickableLink`).
struct ClickableLink: View {
    let title: String
    let url: String
    var systemImage: String = "arrow.up.right.square"

    var body: some View {
        if let destination = URL(string: url), MarkdownText.isSafeToOpen(destination) {
            Link(destination: destination) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.modelInfoIcon)
                    Text(title)
                        .appText(.bodyMedium)
                        .foregroundStyle(AppPalette.link)
                        .underline()
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }
}
