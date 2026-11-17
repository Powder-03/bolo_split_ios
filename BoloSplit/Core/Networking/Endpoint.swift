//
//  Endpoint.swift
//  BoloSplit
//
//  Type-safe HTTP endpoint definitions.
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
    var requiresAuth: Bool = true
    var contentType: String? = "application/json"

    static func get(_ path: String, queryItems: [URLQueryItem] = [], requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .get, queryItems: queryItems, requiresAuth: requiresAuth)
    }

    static func post<T: Encodable>(_ path: String, body: T, queryItems: [URLQueryItem] = [], requiresAuth: Bool = true) throws -> Endpoint {
        let data = try JSONCoders.encoder.encode(body)
        return Endpoint(path: path, method: .post, queryItems: queryItems, body: data, requiresAuth: requiresAuth)
    }

    static func postEmpty(_ path: String, queryItems: [URLQueryItem] = [], requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .post, queryItems: queryItems, body: nil, requiresAuth: requiresAuth, contentType: nil)
    }

    static func patch<T: Encodable>(_ path: String, body: T, requiresAuth: Bool = true) throws -> Endpoint {
        let data = try JSONCoders.encoder.encode(body)
        return Endpoint(path: path, method: .patch, body: data, requiresAuth: requiresAuth)
    }

    static func delete(_ path: String, requiresAuth: Bool = true) -> Endpoint {
        Endpoint(path: path, method: .delete, requiresAuth: requiresAuth, contentType: nil)
    }
}
