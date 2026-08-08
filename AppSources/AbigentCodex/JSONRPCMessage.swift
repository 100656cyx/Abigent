import AbigentCore
import Foundation

public enum JSONRPCID: Codable, Sendable, Equatable, Hashable {
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) { self = .integer(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        }
    }
}

public struct JSONRPCErrorPayload: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: JSONValue?
}

public struct JSONRPCMessage: Codable, Sendable, Equatable {
    public let jsonrpc: String?
    public let id: JSONRPCID?
    public let method: String?
    public let params: JSONValue?
    public let result: JSONValue?
    public let error: JSONRPCErrorPayload?
}

struct JSONRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id: JSONRPCID
    let method: String
    let params: JSONValue
}

struct JSONRPCNotification: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: JSONValue
}

struct JSONRPCResponse: Encodable {
    let jsonrpc = "2.0"
    let id: JSONRPCID
    let result: JSONValue
}
