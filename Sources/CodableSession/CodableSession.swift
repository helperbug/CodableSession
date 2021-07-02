// MIT License
// Copyright (c) 2021 Ben Waidhofer

import Foundation

public struct CodableSessionLibrary {
    public private(set) var version = "0.0.1"
}

/// Codable request wraps URLSession with a JSON Decoder and flattens out all possible errors into one type. The coding tactics used were to avoid the pyrimid of death that is typical when using http request and json.
@available(macOS 12.0, *)
@available(iOS 15.0, *)
public struct CodableRequest {
    /*
     The user and pass can be used to form a basic authorization header using base64 encoding. Similarly, user agent will form a User-Agent header field.
     */
    private let user : String?
    private let pass : String?
    private let userAgent : String?
    
    public init(_ user: String? = nil, _ pass: String? = nil, _ userAgent: String? = nil) {
        self.user = user
        self.pass = pass
        self.userAgent = userAgent
    }
    
    /// Awaitable Http Get Request that decodes the response data into the specified Codable
    /// - Returns: A decoded object populated by the downloaded json
    public func get<D: Decodable>(_ address: String) async throws -> D {
        let getRequest = try makeRequest("GET", address)
        let data = try await data(getRequest)

        return try decode(data) as D
    }
    
    /// Awaitable Http Delete Request
    public func delete(_ address: String) async throws {
        let getRequest = try makeRequest("DELETE", address)
        let _ = try await data(getRequest)
    }

    /// Awaitable Http Post Request that encodes the payload and sets the http body, then decodes the response data into the specified Decodable
    /// - Returns: A decoded object populated by the downloaded json
    public func post<D: Encodable, T: Decodable>(_ address: String, _ payload: D) async throws -> T {
        var postRequest = try makeRequest("POST", address)
        
        do {
            postRequest.httpBody = try JSONEncoder().encode(payload)
        } catch EncodingError.invalidValue(let value, let context) {
            throw CodableRequestError.jsonInvalidValue(value, context)
        } catch {
            throw CodableRequestError.jsonEncoder(error.localizedDescription)
        }
        
        let data = try await data(postRequest)

        return try decode(data) as T
    }

    
    /// Create a http request and set its headers
    /// - Parameters:
    ///   - method: Http method to use
    ///   - address: Create an url with this address
    /// - Returns: The request intialized with the passed in values
    private func makeRequest(_ method: String, _ address: String) throws -> URLRequest {
        guard let url = URL(string: address) else {
            throw CodableRequestError.badAddress(address)
        }
        
        // The Request that will asynchronously round trip to the address
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Optionally, user and pass will create an authorization header
        if let user = user, let pass = pass {
            if let credentials = "\(user):\(pass)".data(using: .utf8) {
                let authToken = credentials.base64EncodedString()
                request.setValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
            } else {
                throw CodableRequestError.badToken
            }
        }
        
        // Optional user agent header
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        return request
    }
    
    private func data(_ request: URLRequest) async throws -> Data {
        // Using let optionals with guard statements instead of nested ifs to fight the "pyramid of doom"
        let sessionData : Data?
        let sessionResponse : URLResponse?
        
        do {
            // URL Session uses Async/Await in Swift 5.5
            (sessionData, sessionResponse) = try await URLSession.shared.data(for: request)
        } catch {
            throw CodableRequestError.taskFailed(error.localizedDescription)
        }
        
        // response validation
        guard let data = sessionData, let response = sessionResponse else {
            throw CodableRequestError.noResponse
        }
        
        // response health check
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CodableRequestError.badResponse
        }
        
        // anything besides 200 is an error
        if ![200, 201].contains(httpResponse.statusCode) {
            // package up the response data as an error string
            if let message = String(data: data, encoding: String.Encoding.utf8) {
                // pass the status code and error text along with the error
                throw CodableRequestError.unhealthyMessage(httpResponse.statusCode, message)
            } else {
                // no error in response, so just use the code in the error
                throw CodableRequestError.unhealthy(httpResponse.statusCode)
            }
        }
        
        if let data = sessionData {
            return data
        } else {
            throw CodableRequestError.noData
        }
    }

    private func decode<D: Decodable>(_ data: Data) throws -> D {
        // now make sure the healthy response decodes into the expected type
        let decodable : D?
        
        do {
            // assume ISO 8601 date formats
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // decode json results into passed in type
            // return the newly instantiated decoded model
            decodable = try decoder.decode(D.self, from: data)
        } catch let DecodingError.dataCorrupted(context) {
            // the json data did not parse
            throw CodableRequestError.jsonDataCorrupted(context)
        } catch let DecodingError.keyNotFound(key, context) {
            // decodable property did not find data in the incoming json
            throw CodableRequestError.jsonKeyNotFound(key, context, String(data: data, encoding: .utf8) ?? "")
        } catch let DecodingError.valueNotFound(value, context) {
            // decodable property found bad data in json
            throw CodableRequestError.jsonValueNotFound(value, context)
        } catch let DecodingError.typeMismatch(type, context)  {
            // most often a null value in a non-optional decodable property
            throw CodableRequestError.jsonTypeMismatch(type, context)
        } catch {
            // some other json decoder error
            throw CodableRequestError.jsonDecoder(error.localizedDescription)
        }

        // make sure there is a result
        if let result = decodable {
            return result
        } else {
            throw CodableRequestError.noResult
        }
    }
}

public enum CodableRequestError : Error {
    case badToken
    case badAddress(String)
    case taskFailed(String)
    case noResponse
    case badResponse
    case noResult
    case noData
    case unhealthyMessage(Int, String)
    case unhealthy(Int)
    case jsonDataCorrupted(DecodingError.Context)
    case jsonKeyNotFound(CodingKey, DecodingError.Context, String)
    case jsonValueNotFound(Any.Type, DecodingError.Context)
    case jsonTypeMismatch(Any.Type, DecodingError.Context)
    case jsonDecoder(String)
    case jsonEncoder(String)
    case jsonInvalidValue(Any, EncodingError.Context)
    
    public var title: String {
        switch self {
        case .badToken: return "Failed to create authorization token"
        case .badAddress: return "URL was not well formed"
        case .taskFailed: return "The URL Session Data Task never returned"
        case .noResponse: return "No Response"
        case .badResponse: return "Http Response was poorly formed"
        case .noData: return "There was no data in the response"
        case .noResult: return "There was no Result"
        case .unhealthy: return "Unhealthy Http Reponse Status"
        case .unhealthyMessage: return "Unhealthy Http Reponse Status with Message"
        case .jsonDataCorrupted: return "JSON Decoder Data Corrupted"
        case .jsonKeyNotFound: return "JSON Decoder Key Not Found"
        case .jsonValueNotFound: return "JSON Decoder Value Not Found"
        case .jsonTypeMismatch: return "JSON Decoder Type Mismatch"
        case .jsonDecoder: return "JSON Decoder Error"
        case .jsonEncoder: return "JSON Encoder Error"
        case .jsonInvalidValue: return "JSON Encoder Invalid Value"
        }
    }
}
