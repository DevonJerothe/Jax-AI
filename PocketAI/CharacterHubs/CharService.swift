import Foundation 
import SwiftLLMSDK

enum ContentType: String {
    case json = "application/json"
    case formData = "application/x-www-form-urlencoded"
}

public struct CharService {
    let baseUrl: String 
    var urlSession: URLSession = .shared
    var decoder: JSONDecoder = JSONDecoder()
    var defaultHeaders: () -> [String: String] = { [:] }

    func sendRequest<T: Decodable>(
        forType: T.Type, 
        path: String, 
        method: String = "GET",
        requestBody: Data? = nil, 
        formData: [String: String] = [:],
        requestParams: [String: String] = [:],
        contentType: ContentType = .json
    ) async -> Result<T, APIError> {
        guard var url = URL(string: "\(baseUrl)\(path)") else {
            return .failure(.invalidURL)
        }

        if requestParams.isEmpty == false {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            urlComponents?.queryItems = requestParams.map { URLQueryItem(name: $0.key, value: $0.value) }

            guard let urlQuery = urlComponents?.url else {
                return .failure(.invalidURL)
            }
            url = urlQuery
        }

        var request = URLRequest(url: url) 
        request.httpMethod = method

        switch contentType {
            case .json: 
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = requestBody
            case .formData:
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = formData.map { "\($0.key)=\($0.value.formURLEncoded)" }.joined(separator: "&").data(using: .utf8)
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let headers = defaultHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await urlSession.data(for: request) 
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let http = response as? HTTPURLResponse {
                    if let body = String(data: data, encoding: .utf8) {
                        print("error: status=\(http.statusCode) url=\(request.url?.absoluteString ?? "") body=\(body.prefix(500))")
                    } else {
                        print("error: status=\(http.statusCode) url=\(request.url?.absoluteString ?? "") [non-utf8 body]")
                    }
                }
                return .failure(.invalidResponse) 
            }
            

            do {
                let decodedData = try decoder.decode(forType, from: data) 
                return .success(decodedData) 
            } catch {
                return .failure(.invalidData)
            }

        } catch let error as URLError where error.code == .timedOut {
            return .failure(.timeout)
        } catch {
            return .failure(.invalidData)
        }
    }

    func getData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if !(200...299).contains(httpResponse.statusCode) {
            throw APIError.serverError(code: httpResponse.statusCode)
        }

        return data
    }
}

private extension String {
    var formURLEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed 
        allowed.remove(charactersIn: "+&=")

        return addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: " ", with: "+") ?? self
    }
}