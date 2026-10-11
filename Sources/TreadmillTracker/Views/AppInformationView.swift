import SwiftUI

/// Bundled content remains readable offline; the same source generates the public support site.
struct AppInformationView: View {
    enum Page {
        case privacy, support

        var title: String { self == .privacy ? "プライバシーポリシー" : "サポート・使い方" }
    }

    let page: Page

    private struct Content: Decodable {
        let publisher: String
        let email: String
        let updated: String
        let privacy: Document
        let support: Document
    }

    private struct Document: Decodable {
        let url: URL
        let sections: [ParagraphSection]
    }

    private struct ParagraphSection: Decodable {
        let title: String
        let paragraphs: [String]
    }

    private static let content: Content? = {
        guard let url = Bundle.main.url(forResource: "AppInformation", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Content.self, from: data)
    }()

    var body: some View {
        Group {
            if let content = Self.content {
                let document = page == .privacy ? content.privacy : content.support
                List {
                    Section {
                        Text("更新日：\(content.updated)")
                            .font(.footnote).foregroundStyle(Theme.secondary)
                        Link("Webで開く", destination: document.url)
                    }
                    ForEach(document.sections.indices, id: \.self) { index in
                        let section = document.sections[index]
                        Section(section.title) {
                            ForEach(section.paragraphs.indices, id: \.self) { paragraph in
                                Text(section.paragraphs[paragraph])
                                    .font(.body).textSelection(.enabled)
                            }
                        }
                    }
                    Section("お問い合わせ") {
                        Text(content.publisher)
                        if let emailURL = URL(string: "mailto:\(content.email)") {
                            Link(content.email, destination: emailURL)
                        }
                    }
                }
                .sportForm()
            } else {
                ContentUnavailableView("案内を読み込めませんでした", systemImage: "doc.text")
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
