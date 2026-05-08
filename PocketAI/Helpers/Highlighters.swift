//
//  Highlighters.swift
//  PocketAI
//
//  Created by devon jerothe on 3/12/25.
//

import SwiftUI
import MarkdownUI
import Splash

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let syntaxHighlighter: SyntaxHighlighter<TextOutputFormat>

    init(theme: Splash.Theme) {
        self.syntaxHighlighter = SyntaxHighlighter(format: TextOutputFormat(theme: theme))
    }

    func highlightCode(_ content: String, language: String?) -> Text {
        guard language != nil else {
            return Text(content)
        }

        return self.syntaxHighlighter.highlight(content)
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static func splash(theme: Splash.Theme) -> Self {
        SplashCodeSyntaxHighlighter(theme: theme)
    }
}

struct AsyncImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        if let url = url {
            AsyncImage(url: url) { state in 
                switch state {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipped()
                    case .failure(_):
                        HStack {
                            Spacer() 
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
                            Spacer()
                        }
                    case .empty: 
                        EmptyView()
                    @unknown default:
                        HStack {
                            Spacer() 
                            ProgressView()
                            Spacer()
                        }
                }
            }
        }
    }
}

struct AsyncInlineImageProvider: InlineImageProvider {
    let maxWidth = UIApplication.currentScreenWidth * 1

    func image(with url: URL, label: String) async throws -> Image {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let uiImage = UIImage(data: data) else {
            throw URLError(.cannotDecodeRawData)
        }

        let size = uiImage.size
        let ratio = maxWidth / max(size.width, size.height)

        if ratio < 1.0 {
            let targetSize = CGSize(width: size.width * ratio, height: size.height * ratio)

            if let thumbnail = uiImage.preparingThumbnail(of: targetSize) {
                return Image(uiImage: thumbnail)
            }
        }

        return Image(uiImage: uiImage)
    
    }
}