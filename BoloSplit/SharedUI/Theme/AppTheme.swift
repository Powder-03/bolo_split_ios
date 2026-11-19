//
//  AppTheme.swift
//  BoloSplit
//
//  Splitwise-inspired colors, gradients, motion presets, and semantic helpers.
//

import SwiftUI

enum AppTheme {
    static let brand = Color.teal
    static let brandAccent = Color(red: 0.06, green: 0.68, blue: 0.58)
    static let owedPositive = Color(red: 0.11, green: 0.65, blue: 0.45) // Splitwise green
    static let owedNegative = Color(red: 0.90, green: 0.36, blue: 0.24) // Splitwise coral-orange
    static let settledNeutral = Color.secondary

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [.teal, brandAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func balanceColor(for amount: Decimal) -> Color {
        if amount > 0 { return owedPositive }
        if amount < 0 { return owedNegative }
        return settledNeutral
    }

    static func categoryIcon(for category: String?) -> String {
        switch (category ?? "").lowercased() {
        case "food", "dining", "dinner", "lunch", "coffee", "chai", "breakfast", "snacks":
            return "fork.knife"
        case "fuel", "petrol", "diesel", "gas":
            return "fuelpump.fill"
        case "travel", "cab", "uber", "ola", "transport", "flight", "train", "auto":
            return "car.fill"
        case "groceries", "grocery", "milk", "vegetables":
            return "cart.fill"
        case "shopping", "clothes", "amazon", "flipkart":
            return "bag.fill"
        case "rent", "utilities", "bills", "electricity", "wifi", "internet":
            return "house.fill"
        case "entertainment", "movies", "netflix", "party":
            return "ticket.fill"
        default:
            return "indianrupeesign.circle.fill"
        }
    }

    static func categoryColor(for category: String?) -> Color {
        switch (category ?? "").lowercased() {
        case "food", "dining", "dinner", "lunch", "coffee", "chai", "breakfast", "snacks":
            return .orange
        case "fuel", "petrol", "diesel", "gas":
            return .indigo
        case "travel", "cab", "uber", "ola", "transport", "flight", "train", "auto":
            return .blue
        case "groceries", "grocery", "milk", "vegetables":
            return owedPositive
        case "shopping", "clothes", "amazon", "flipkart":
            return .pink
        case "rent", "utilities", "bills", "electricity", "wifi", "internet":
            return .purple
        case "entertainment", "movies", "netflix", "party":
            return .mint
        default:
            return brand
        }
    }

    static func avatarColor(for name: String) -> Color {
        let palette: [Color] = [
            .teal,
            Color(red: 0.14, green: 0.56, blue: 0.78),
            Color(red: 0.36, green: 0.45, blue: 0.85),
            Color(red: 0.11, green: 0.65, blue: 0.45),
            Color(red: 0.82, green: 0.44, blue: 0.22),
            Color(red: 0.62, green: 0.38, blue: 0.78)
        ]
        let hash = name.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}

enum AppMotion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let gentle = Animation.spring(response: 0.46, dampingFraction: 0.86)
    static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.66)
    static let quick = Animation.easeOut(duration: 0.2)
}
