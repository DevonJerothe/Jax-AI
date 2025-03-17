//
//  ThemeExtension.swift
//  PocketAI
//
//  Created by devon jerothe on 3/13/25.
//

import SwiftUI
import MarkdownUI

extension Theme {
    static let rolePlay = Theme()
        .code {
            FontStyle(.italic)
            FontWeight(.bold)
            ForegroundColor(.yellow)
        }

    static let userRolePlay = Theme()
        .paragraph { config in
            config.label
                .foregroundStyle(.black)
        }
        .code {
            FontStyle(.italic)
            FontWeight(.bold)
            ForegroundColor(.red)
        }
}
