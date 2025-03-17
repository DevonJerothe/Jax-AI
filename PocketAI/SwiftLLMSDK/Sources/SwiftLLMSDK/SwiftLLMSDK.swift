// The Swift Programming Language
// https://docs.swift.org/swift-book


import Foundation

public protocol KoboldAPIRequest {
    var urlSession: URLSession { get}
    var baseURL: String { get }
}

public protocol KoboldAPIBase: KoboldAPIRequest {
    func getMaxContextLength() async -> Result<Int, APIError>
    func getMaxLength() async -> Result<Int, APIError>
    func getVersion() async -> Result<String, APIError>
    func getModel() async -> Result<String, APIError>
    func sendMessage(promptModel: PromptModel) async -> Result<PromptResponse, APIError>
}

public protocol KoboldAPIExtras: KoboldAPIRequest {}



extension KoboldAPIRequest {
    func sendPrompt(prompt: PromptModel) async -> Result<PromptResponse, APIError> {

        guard let baseURL = URL(string: baseURL + "/api/v1/generate") else {
            return .failure(.invalidURL)
        }
        
        do {
            // Convert prompt model to JSON data
            let requestData = prompt.toJSON()
            
            // Create the request
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = requestData.data(using: .utf8)

            // Send the request
            let (data, response) = try await urlSession.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            
            // Check for successful status code (200-299)
            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(.serverError(code: httpResponse.statusCode))
            }
            
            // Decode the response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let promptResponse = try decoder.decode(PromptResponse.self, from: data)
                return .success(promptResponse)
            } catch {
                return .failure(.decodingError)
            }
        } catch {
            return .failure(.invalidData)
        }
    }

    func getInt(endpoint: String) async -> Result<Int, APIError> {
        guard let baseURL = URL(string: baseURL + endpoint) else {
            return .failure(.invalidURL)
        }

        do {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(.serverError(code: httpResponse.statusCode))
            }

            do {
                let decoder = JSONDecoder()
                let intResponse = try decoder.decode(IntResponse.self, from: data)
                return .success(intResponse.value)
            } catch {
                return .failure(.decodingError)
            }

        } catch {
            return .failure(.invalidData)
        }
    }

    func getString(endpoint: String) async -> Result<String, APIError> {
        guard let baseURL = URL(string: baseURL + endpoint) else {
            return .failure(.invalidURL)
        }

        do {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(.serverError(code: httpResponse.statusCode))
            }

            do {
                let decoder = JSONDecoder()
                let stringResponse = try decoder.decode(StringResponse.self, from: data)
                return .success(stringResponse.result)
            } catch {
                return .failure(.decodingError)
            }
        } catch {
            return .failure(.invalidData)
        }
    }
}


public struct KoboldAPI: KoboldAPIBase, KoboldAPIExtras {
    
    public var urlSession: URLSession
    public var baseURL: String

    public init(urlSession: URLSession, host: String, port: Int) {
        self.urlSession = urlSession
        self.baseURL = "http://\(host):\(port)"
    }

    public func getMaxContextLength() async -> Result<Int, APIError> {
        await getInt(endpoint: "/api/v1/config/max_context_length")
    }

    public func getMaxLength() async -> Result<Int, APIError> {
        await getInt(endpoint: "/api/v1/config/max_length")
    }

    public func getVersion() async -> Result<String, APIError> {
        await getString(endpoint: "/api/v1/info/version")
    }

    public func getModel() async -> Result<String, APIError> {
        await getString(endpoint: "/api/v1/model")
    }

    public func sendMessage(promptModel: PromptModel) async -> Result<PromptResponse, APIError> {
        await sendPrompt(prompt: promptModel)
    }

}
