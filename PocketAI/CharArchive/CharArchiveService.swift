import Foundation 
import SwiftLLMSDK

public protocol CharArchiveServiceProtocol {
    func getRandomCharacters(count: Int) async -> Result<[CharHubModel], APIError>
    func getLatestCharacters(count: Int) async -> Result<[CharHubModel], APIError>
    func searchCharacters(query: String, page: Int, count: Int) async -> Result<CharHubSearchResult, APIError>
}

public class CharArchiveService: CharArchiveServiceProtocol {

    public var urlSession: URLSession = URLSession.shared
    public var baseUrl: String = "https://char-archive.evulid.cc/api/archive/"
    public var timeoutInterval: TimeInterval = 60

    public init() {}

    public func getRandomCharacters(
        count: Int = 5
    ) async -> Result<[CharHubModel], APIError> {
        return await sendRequest(
            path: "/v1/random-character", 
            requestParams: ["count": "\(count)"]
        ) 
    }

    public func getLatestCharacters(
        count: Int = 5
    ) async -> Result<[CharHubModel], APIError> {
        return await sendRequest(
            path: "/v1/latest-character", 
            requestParams: ["count": "\(count)"]
        ) 
    }

    public func searchCharacters(
        query: String,
        page: Int = 1, 
        count: Int = 10
    ) async -> Result<CharHubSearchResult, APIError> {
        return await sendRequest(
            forType: CharHubSearchResult.self, 
            path: "/v3/search/query", 
            requestParams: [
                "query": query, 
                "page": "\(page)", 
                "count": "\(count)"]
        )
    }

    func getCharacter(path: String, source: String) async -> Result<CharacterCardModel, APIError> {
        let result =  await sendRequest(
            forType: CharacterCard.self, 
            path: "/v1/\(source)/def/character/\(path)"
        ) 

        switch result {
            case .success(let character): 
                let charCard = CharacterCardModel.init(fromChub: character)
                return .success(charCard)
            case .failure(let error): 
                print("Error getting character: \(error)")
                return .failure(error)
        }
    } 
}

extension CharArchiveService {
    
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

    private func sendRequest<T: Decodable>(
        forType: T.Type, 
        path: String,
        method: String = "GET",
        requestBody: Data? = nil, 
        requestParams: [String: String] = [:]
    ) async -> Result<T, APIError> {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            return .failure(.invalidURL)
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = requestParams.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = urlComponents?.url else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = requestBody

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                if let http = response as? HTTPURLResponse {
                    if let body = String(data: data, encoding: .utf8) {
                        print("CharArchiveService error: status=\(http.statusCode) url=\(request.url?.absoluteString ?? "") body=\(body.prefix(500))")
                    } else {
                        print("CharArchiveService error: status=\(http.statusCode) url=\(request.url?.absoluteString ?? "") [non-utf8 body]")
                    }
                }
                return .failure(.invalidResponse)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(.serverError(code: httpResponse.statusCode))
            }   

            let decoder = JSONDecoder()

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
    
    private func sendRequest( 
        path: String,
        method: String = "GET",
        requestBody: Data? = nil, 
        requestParams: [String: String] = [:]
    ) async -> Result<[CharHubModel], APIError> {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            return .failure(.invalidURL)
        }

        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = requestParams.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = urlComponents?.url else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = requestBody

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return .failure(.invalidResponse)
            }

            if !(200...299).contains(httpResponse.statusCode) {
                return .failure(.serverError(code: httpResponse.statusCode))
            }

            let decoder = JSONDecoder() 

            do {
                let decodedData = try decoder.decode([CharHubModel].self, from: data)
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
}
