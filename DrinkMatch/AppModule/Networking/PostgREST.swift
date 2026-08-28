import Foundation

/// Table and RPC operations built on RestClient's raw request(), covering
/// every shape SupabaseRepository actually uses (select/insert/update/delete/
/// upsert, RPC with or without params, Edge Function invocation).
enum PostgREST {
    static func select<T: Decodable>(
        _ table: String,
        columns: String,
        filters: [URLQueryItem] = [],
        order: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        var items = [URLQueryItem(name: "select", value: columns)] + filters
        if let order { items.append(URLQueryItem(name: "order", value: order)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        let data = try await RestClient.request("rest/v1/\(table)", method: .get, queryItems: items)
        return try RestClient.decode(data)
    }

    static func insert(_ table: String, _ payload: some Encodable) async throws {
        let body = try RestClient.encode(payload)
        try await RestClient.request("rest/v1/\(table)", method: .post, body: body)
    }

    static func update(_ table: String, _ patch: some Encodable, filters: [URLQueryItem]) async throws {
        let body = try RestClient.encode(patch)
        try await RestClient.request("rest/v1/\(table)", method: .patch, queryItems: filters, body: body)
    }

    static func delete(_ table: String, filters: [URLQueryItem]) async throws {
        try await RestClient.request("rest/v1/\(table)", method: .delete, queryItems: filters)
    }

    /// Upserts and decodes the row(s) actually written back — used where the
    /// caller needs the server-generated id (e.g. a newly upserted schedule
    /// entry). `Prefer: resolution=merge-duplicates` makes a conflicting row
    /// update instead of erroring; `return=representation` is what makes
    /// PostgREST hand the row back at all (its default is to return nothing).
    static func upsertReturningFirst<R: Decodable>(
        _ table: String,
        _ payload: some Encodable,
        onConflict: String,
        select: String
    ) async throws -> R {
        let body = try RestClient.encode(payload)
        let items = [
            URLQueryItem(name: "on_conflict", value: onConflict),
            URLQueryItem(name: "select", value: select),
        ]
        let data = try await RestClient.request(
            "rest/v1/\(table)", method: .post, queryItems: items, body: body,
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
        )
        let rows: [R] = try RestClient.decode(data)
        guard let first = rows.first else {
            throw RestClient.RequestError(status: 0, body: "upsert into \(table) returned no rows")
        }
        return first
    }

    /// Upsert where the caller doesn't need the row back (just create-or-update).
    static func upsert(_ table: String, _ payload: some Encodable, onConflict: String) async throws {
        let body = try RestClient.encode(payload)
        let items = [URLQueryItem(name: "on_conflict", value: onConflict)]
        try await RestClient.request(
            "rest/v1/\(table)", method: .post, queryItems: items, body: body,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
    }

    static func rpc<R: Decodable>(_ name: String, params: some Encodable) async throws -> R {
        let body = try RestClient.encode(params)
        let data = try await RestClient.request("rest/v1/rpc/\(name)", method: .post, body: body)
        return try RestClient.decode(data)
    }

    static func rpcVoid(_ name: String, params: some Encodable) async throws {
        let body = try RestClient.encode(params)
        try await RestClient.request("rest/v1/rpc/\(name)", method: .post, body: body)
    }

    static func rpc<R: Decodable>(_ name: String) async throws -> R {
        let data = try await RestClient.request("rest/v1/rpc/\(name)", method: .post, body: Data("{}".utf8))
        return try RestClient.decode(data)
    }

    static func rpcVoid(_ name: String) async throws {
        try await RestClient.request("rest/v1/rpc/\(name)", method: .post, body: Data("{}".utf8))
    }

    static func invokeFunction(_ name: String, body: some Encodable) async throws {
        let encoded = try RestClient.encode(body)
        try await RestClient.request("functions/v1/\(name)", method: .post, body: encoded)
    }
}
