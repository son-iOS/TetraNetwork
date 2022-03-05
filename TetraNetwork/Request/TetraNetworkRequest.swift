//
//  TetraNetworkRequest.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 11/21/20.
//

import Foundation

/// Enum specifying the request method
public enum TetraHttpMethod: String {
    case GET
    case PUT
    case POST
    case DELETE
}

/// Conform to this protocol in order to make a request with using `TetraNetworkWorker`
public protocol TetraNetworkRequest {
    /// The base url of the request, don't add any path, query, etc. here.
    var baseUrl: String { get }
    
    /// The path of the endpoint
    var paths: [String]? { get }
    
    /// The http method for this request
    var method: TetraHttpMethod { get }
    
    /// Dictionary that hold the queries for this request
    var queries: [String: Any]? { get }
    
    /// Dictionary that hold the params for this request
    var params: [String: Any]? { get }
    
    /// Dictionary that hold the headers for this request
    var headers: [String: Any]? { get }
    
    /// Data that will be inserted as the body of the request
    var body: Data? { get }
}

internal extension TetraNetworkRequest {
    var endPoint: String {
        let path = (paths ?? []).joined(separator: "/")
        return "\(baseUrl)/\(path.safeUrlString)"
    }
    
    var urlRequest: URLRequest? {
        var urlString = endPoint

        if let params = self.params, !params.isEmpty {
            params.keys.sorted().forEach { (key) in
                urlString += "/"
                urlString += "\(key.safeUrlString)/\("\(params[key] ?? "")".safeUrlString)"
            }
        }

        if let query = self.queries, !query.isEmpty {
            urlString += "?"
            query.keys.sorted().forEach({ (key) in
                urlString += "\(key.safeUrlString)=\("\(query[key] ?? "")".safeUrlString)&"
            })
        }

        guard let url = URL(string: urlString) else {
            return nil
        }

        var urlRequest = URLRequest(url: url)

        self.headers?.forEach({ (key, value) in
            urlRequest.addValue("\(value)", forHTTPHeaderField: key)
        })

        urlRequest.httpBody = self.body
        urlRequest.httpMethod = self.method.rawValue

        return urlRequest
    }
}

/// Default implementation of a `TetraNetworkRequest`.
/// Also conforms to `TetraNetworkCachable` and `TetraNetworkBufferable`
public struct DefaultTetraNetworkRequest: TetraNetworkRequest, TetraNetworkCachable, TetraNetworkBufferable {
    
    public let baseUrl: String
    public let paths: [String]?
    public let method: TetraHttpMethod
    public private(set) var headers: [String: Any]?
    public let params: [String: Any]?
    public let queries: [String: Any]?
    public let body: Data?
    
    public init(baseUrl: String,
                paths: [String]? = nil,
                method: TetraHttpMethod,
                headers: [String : Any]? = nil,
                params: [String : Any]? = nil,
                queries: [String : Any]? = nil,
                body: Data? = nil) {
        self.baseUrl = baseUrl
        self.paths = paths
        self.method = method
        self.headers = headers
        self.params = params
        self.queries = queries
        self.body = body
    }

    public var hash: AnyHashable {
        var result = method.rawValue
        result += urlRequest?.url?.absoluteString ?? ""
        headers?.keys.sorted().forEach({ key in
            result += key + "\(headers?[key] ?? "")"
        })
        result += body?.base64EncodedString() ?? ""
        return result
    }
    
    /// Convinient method to add api key to the headers of this request.
    /// Defaulting the name to be "x-api-key".
    public mutating func setApiKey(
        _ key: String, name: String = "x-api-key"
    ) {
        if headers == nil {
            headers = [name: key]
        } else {
            headers?[name] = key
        }
    }
    
    /// Convinient method to add content type to the headers of this request.
    /// Defaulting the value to be "application/json".
    public mutating func setContentType(
        _ contentType: String = "application/json"
    ) {
        if headers == nil {
            headers = ["Content-Type": contentType]
        } else {
            headers?["Content-Type"] = contentType
        }
    }
    
    /// Convinient method to add auth token to the headers of this request.
    /// Defaulting the prefix to be "Bearer".
    public mutating func setAuthToken(
        _ token: String, prefix: String = "Bearer"
    ) {
        if headers == nil {
            headers = ["Authorization": "\(prefix) \(token)"]
        } else {
            headers?["Authorization"] = "\(prefix) \(token)"
        }
    }
}
