//
//  AccountHelpers.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import Foundation

// MARK: - Account UI Helpers

func iconForAccountType(_ type: AccountType) -> String {
    switch type {
    case .checking:
        return "banknote"
    case .savings:
        return "banknote.fill"
    case .creditCard:
        return "creditcard"
    case .loan:
        return "doc.text"
    case .mortgage:
        return "house"
    case .ira:
        return "chart.line.uptrend.xyaxis"
    case .retirement401k:
        return "chart.pie"
    case .brokerage:
        return "chart.bar"
    case .other:
        return "folder"
    }
}

func colorForAccountType(_ type: AccountType) -> Color {
    switch type {
    case .checking:
        return .blue
    case .savings:
        return .green
    case .creditCard:
        return .orange
    case .loan:
        return .red
    case .mortgage:
        return .purple
    case .ira:
        return .indigo
    case .retirement401k:
        return .teal
    case .brokerage:
        return .pink
    case .other:
        return .gray
    }
}

// MARK: - Formatting Helpers

func formatCurrency(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    formatter.currencySymbol = "$"
    return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
}

func formatPercent(_ percent: Decimal, decimalPlaces: Int = 2) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = decimalPlaces
    formatter.minimumFractionDigits = decimalPlaces
    return formatter.string(from: percent as NSDecimalNumber) ?? "0%"
}

func formatDecimalForEditing(_ value: Decimal) -> String {
    if value == 0 {
        return ""
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    return formatter.string(from: value as NSDecimalNumber) ?? ""
}

// MARK: - Decimal Parsing Helpers

func parseDecimal(from string: String) -> Decimal? {
    let cleaned = string.replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    if cleaned.isEmpty {
        return 0
    }
    
    return Decimal(string: cleaned)
}

func parsePercent(from string: String) -> Decimal? {
    let cleaned = string.replacingOccurrences(of: "%", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    if cleaned.isEmpty {
        return 0
    }
    
    if let decimal = Decimal(string: cleaned) {
        return decimal / 100 // Convert percentage to decimal
    }
    
    return nil
}

// MARK: - Balance Color Helpers

func balanceColor(for balance: Decimal, accountType: AccountType) -> Color {
    switch accountType {
    case .creditCard, .loan, .mortgage:
        // For debt accounts, positive balance is debt (bad)
        return balance > 0 ? .primary : .secondary
    case .checking, .savings, .ira, .retirement401k, .brokerage:
        // For asset accounts, negative balance is bad
        return balance < 0 ? .red : .primary
    case .other:
        return .primary
    }
}

func utilizationColor(_ utilization: Decimal) -> Color {
    if utilization >= 90 {
        return .red
    } else if utilization >= 70 {
        return .orange
    } else if utilization >= 30 {
        return .yellow
    } else {
        return .green
    }
}

// MARK: - Extensions

extension Decimal {
    func pow(_ exponent: Int) -> Decimal {
        var result = Decimal(1)
        for _ in 0..<exponent {
            result *= self
        }
        return result
    }
}

// Function to handle compound interest calculations
func pow(_ base: Decimal, _ exponent: Int) -> Decimal {
    var result = Decimal(1)
    var base = base
    var exponent = exponent
    
    while exponent > 0 {
        if exponent % 2 == 1 {
            result *= base
        }
        base *= base
        exponent /= 2
    }
    
    return result
}