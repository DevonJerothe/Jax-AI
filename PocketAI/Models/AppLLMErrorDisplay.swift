//
//  AppLLMErrorDisplay.swift
//  PocketAI
//
//  Created by Codex on 6/25/26.
//

import Foundation
import SwiftLLMSDK

struct AppLLMErrorDisplay: Equatable, Sendable {
    var title: String
    var message: String
    var recoverySuggestion: String?
    var category: LLMErrorCategory?
    var provider: LLMProvider?
    var source: LLMErrorSource?
    var statusCode: Int?
    var providerCode: String?
    var providerType: String?

    static func from(_ error: APIError, provider fallbackProvider: LLMProvider = .unknown) -> AppLLMErrorDisplay {
        switch error {
        case .llmError(let llmError):
            return from(llmError)
        case .invalidURL:
            return AppLLMErrorDisplay(
                title: "Connection Error",
                message: "The provider URL is invalid.",
                recoverySuggestion: "Check the provider URL in Connection Settings.",
                provider: fallbackProvider
            )
        case .invalidResponse:
            return AppLLMErrorDisplay(
                title: "Connection Error",
                message: "The provider returned an invalid response.",
                recoverySuggestion: "Check the provider connection and try again.",
                provider: fallbackProvider
            )
        case .invalidData:
            return AppLLMErrorDisplay(
                title: "Response Error",
                message: "The provider returned invalid data.",
                recoverySuggestion: "Try again or switch models if this keeps happening.",
                provider: fallbackProvider
            )
        case .decodingError:
            return AppLLMErrorDisplay(
                title: "Response Error",
                message: "The provider response could not be decoded.",
                recoverySuggestion: "Try again or check whether the endpoint is OpenAI-compatible.",
                provider: fallbackProvider
            )
        case .timeout:
            return AppLLMErrorDisplay(
                title: "Timeout",
                message: "The request timed out.",
                recoverySuggestion: "Try again, or reduce the response length if the provider is slow.",
                category: .timeout,
                provider: fallbackProvider
            )
        case .serverError(let code):
            return AppLLMErrorDisplay(
                title: "Server Error",
                message: "The provider returned HTTP \(code).",
                recoverySuggestion: "Try again later or check the provider status.",
                category: .serverError,
                provider: fallbackProvider,
                statusCode: code
            )
        case .invalidService:
            return AppLLMErrorDisplay(
                title: "Configuration Error",
                message: "The selected service is not valid for this request.",
                recoverySuggestion: "Check the selected provider in Connection Settings.",
                provider: fallbackProvider
            )
        case .unsupportedURLImport:
            return AppLLMErrorDisplay(
                title: "Import Error",
                message: "This URL is not supported.",
                provider: fallbackProvider
            )
        }
    }

    static func from(_ error: LLMError) -> AppLLMErrorDisplay {
        AppLLMErrorDisplay(
            title: title(for: error.category),
            message: error.message,
            recoverySuggestion: recoverySuggestion(for: error.category),
            category: error.category,
            provider: error.provider,
            source: error.source,
            statusCode: error.httpStatusCode,
            providerCode: error.providerCode,
            providerType: error.providerType
        )
    }

    var debugSummary: String {
        [
            provider.map { "provider=\($0.rawValue)" },
            source.map { "source=\($0.rawValue)" },
            category.map { "category=\($0.rawValue)" },
            statusCode.map { "status=\($0)" },
            providerCode.map { "providerCode=\($0)" },
            providerType.map { "providerType=\($0)" },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    func asLLMError(provider fallbackProvider: LLMProvider) -> LLMError {
        LLMError(
            message: message,
            provider: provider ?? fallbackProvider,
            source: source ?? .sdk,
            category: category ?? .unknown,
            httpStatusCode: statusCode,
            providerCode: providerCode,
            providerType: providerType
        )
    }

    private static func title(for category: LLMErrorCategory) -> String {
        switch category {
        case .authentication:
            return "Authentication Error"
        case .authorization:
            return "Permission Error"
        case .rateLimit:
            return "Rate Limit"
        case .quotaExceeded:
            return "Quota Exceeded"
        case .contextLength:
            return "Context Too Long"
        case .invalidRequest:
            return "Invalid Request"
        case .serverError, .unavailable:
            return "Provider Unavailable"
        case .networkError:
            return "Network Error"
        case .decodingError:
            return "Response Error"
        case .cancelled:
            return "Cancelled"
        case .timeout:
            return "Timeout"
        case .unknown:
            return "Provider Error"
        }
    }

    private static func recoverySuggestion(for category: LLMErrorCategory) -> String? {
        switch category {
        case .authentication:
            return "Check your API key or credentials in Connection Settings."
        case .authorization:
            return "Check whether this account or key has access to the selected model."
        case .rateLimit:
            return "Wait a moment before sending another message."
        case .quotaExceeded:
            return "Check your credits, billing, or quota with the provider."
        case .contextLength:
            return "Shorten the conversation, memory, prompt, or max response length."
        case .invalidRequest:
            return "Review the selected model and request settings."
        case .serverError, .unavailable:
            return "Try again later or check the provider status."
        case .networkError:
            return "Check your network connection and provider URL."
        case .decodingError:
            return "Try again or check whether the endpoint is compatible."
        case .cancelled:
            return nil
        case .timeout:
            return "Try again, or reduce the response length if the provider is slow."
        case .unknown:
            return nil
        }
    }
}
