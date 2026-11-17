//
//  AppTheme.swift
//  BoloSplit
//
//  Splitwise-inspired colors, formatting, and semantic helpers.
//

import SwiftUI

enum AppTheme {
    static let brand = Color.teal
    static let owedPositive = Color(red: 0.11, green: 0.65, blue: 0.45) // Splitwise green
    static let owedNegative = Color(red: 0.90, green: 0.36, blue: 0.24) // Splitwise coral-orange
    static let settledNeutral = Color.secondary

    static func balanceColor(for amount: Decimal) -> Color {
        if amount > 0 { return owedPositive }
        if amount < 0 { return owedNegative }
        return settledNeutral
    }

    static func categoryIcon(for category: String?) -> String {
        switch (category ?? "").lowercased() {
        case "food", "dining", "dinner", "lunch", "coffee", "chai":
            return "fork.knife"
        case "fuel", "petrol", "diesel":
            return "fuelpump.fill"
        case "travel", "cab", "uber", "transport":
            return "car.fill"
        case "groceries", "grocery":
            return "cart.fill"
        case "shopping", "clothes", "amazon":
            return "bag.fill"
        case "rent", "utilities", "bills", "electricity":
            return "house.fill"
        case "entertainment", "movies":
            return "ticket.fill"
        default:
            return "indianrupeesign.circle.fill"
        }
    }
}
