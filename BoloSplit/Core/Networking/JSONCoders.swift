//
//  JSONCoders.swift
//  BoloSplit
//
//  Python/FastAPI-compatible JSON coding (snake_case, microsecond ISO8601 dates, Decimal strings/numbers).
//

import Foundation

enum JSONCoders {
    /// Shared JSONDecoder configured for FastAPI / Pydantic responses.
    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = DateParser.parseISO8601(dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date string: \(dateString)"
            )
        }
        return decoder
    }

    /// Shared JSONEncoder configured for FastAPI / Pydantic requests.
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

enum DateParser {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Handles Python microsecond timestamps (e.g. "2026-11-17T11:20:00.123456+00:00")
    /// as well as standard ISO8601 strings without fractional seconds or timezone.
    static func parseISO8601(_ string: String) -> Date? {
        if let date = withFractionalSeconds.date(from: string) {
            return date
        }
        if let date = withoutFractionalSeconds.date(from: string) {
            return date
        }
        // Fallback for naive Python timestamps lacking a trailing Z / offset
        let isoFallback = ISO8601DateFormatter()
        isoFallback.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return isoFallback.date(from: string)
    }
}

/// Decodes Pydantic `Decimal` values whether FastAPI serializes them as JSON strings ("500.00") or numbers (500.0).
@propertyWrapper
struct JSONDecimal: Codable, Hashable, Sendable {
    var wrappedValue: Decimal

    init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let decimal = try? container.decode(Decimal.self) {
            self.wrappedValue = decimal
            return
        }
        if let string = try? container.decode(String.self),
           let decimal = Decimal(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.wrappedValue = decimal
            return
        }
        if let double = try? container.decode(Double.self) {
            self.wrappedValue = Decimal(double)
            return
        }
        if let int = try? container.decode(Int.self) {
            self.wrappedValue = Decimal(int)
            return
        }
        throw DecodingError.typeMismatch(
            Decimal.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Decimal as number or string.")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

/// Optional variant of `JSONDecimal` for nullable Decimal fields.
@propertyWrapper
struct OptionalJSONDecimal: Codable, Hashable, Sendable {
    var wrappedValue: Decimal?

    init(wrappedValue: Decimal?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.wrappedValue = nil
            return
        }
        self.wrappedValue = try JSONDecimal(from: decoder).wrappedValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value)
        } else {
            try container.encodeNil()
        }
    }
}

extension KeyedDecodingContainer {
    func decode(_ type: OptionalJSONDecimal.Type, forKey key: Key) throws -> OptionalJSONDecimal {
        try decodeIfPresent(type, forKey: key) ?? OptionalJSONDecimal(wrappedValue: nil)
    }
}

enum CurrencyFormatter {
    private static let inrFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func formatINR(_ amount: Decimal) -> String {
        inrFormatter.string(from: amount as NSDecimalNumber) ?? "₹\(amount)"
    }
}
