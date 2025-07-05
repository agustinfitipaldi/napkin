//
//  Models.swift
//  napkin
//
//  Created by Claude Opus on 7/5/25.
//

import Foundation
import SwiftData

// MARK: - Enums

enum AccountType: String, Codable, CaseIterable, Comparable {
    case checking = "Checking"
    case savings = "Savings"
    case creditCard = "Credit Card"
    case loan = "Loan"
    case mortgage = "Mortgage"
    case ira = "IRA"
    case retirement401k = "401(k)"
    case brokerage = "Brokerage"
    case other = "Other"
    
    var hasAPR: Bool {
        switch self {
        case .creditCard, .loan, .mortgage:
            return true
        default:
            return false
        }
    }
    
    var hasMinimumPayment: Bool {
        switch self {
        case .creditCard, .loan, .mortgage:
            return true
        default:
            return false
        }
    }
    
    var hasCreditLimit: Bool {
        self == .creditCard
    }
    
    static func < (lhs: AccountType, rhs: AccountType) -> Bool {
        let order: [AccountType] = [.checking, .savings, .creditCard, .loan, .mortgage, .ira, .retirement401k, .brokerage, .other]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

enum APRType: String, Codable {
    case fixed = "Fixed"
    case variable = "Variable"  // Prime + margin
}

// MARK: - Models

@Model
final class Account {
    var id: UUID
    var bankName: String
    var accountName: String
    var accountType: AccountType
    var lastFourDigits: String?  // For easy identification
    
    // Credit Details
    var creditLimit: Decimal?  // For credit cards
    
    // APR Details (only for credit accounts)
    var aprType: APRType?
    var fixedAPR: Decimal?  // For fixed rate
    var marginAPR: Decimal?  // For variable (added to prime)
    var maxAPR: Decimal?  // Cap for variable rates
    
    // Payment Details
    var paymentDueDay: Int?  // Day of month (1-31)
    var minimumPaymentAmount: Decimal?  // Fixed minimum
    var minimumPaymentPercent: Decimal?  // Or percentage of balance
    var lateFee: Decimal?
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool  // For soft delete/archive
    var notes: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var balanceEntries: [BalanceEntry]?
    
    init(bankName: String, accountName: String, accountType: AccountType) {
        self.id = UUID()
        self.bankName = bankName
        self.accountName = accountName
        self.accountType = accountType
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
    }
    
    // Computed property for current APR
    func currentAPR(primeRate: Decimal) -> Decimal? {
        guard accountType.hasAPR else { return nil }
        
        switch aprType {
        case .fixed:
            return fixedAPR
        case .variable:
            guard let margin = marginAPR else { return nil }
            let calculated = primeRate + margin
            if let max = maxAPR {
                return min(calculated, max)
            }
            return calculated
        case .none:
            return nil
        }
    }
    
    // Calculate monthly interest on a balance (daily compounding)
    func monthlyInterest(on balance: Decimal, primeRate: Decimal, days: Int = 30) -> Decimal {
        guard let apr = currentAPR(primeRate: primeRate) else { return 0 }
        // Convert APR to daily rate
        let dailyRate = apr / 365 / 100
        // Compound daily: balance * (1 + daily)^days - balance
        let compounded = balance * pow(1 + dailyRate, days)
        return compounded - balance
    }
    
    // Calculate minimum payment (1% + interest, minimum $40 or configured amount)
    func minimumPayment(balance: Decimal, primeRate: Decimal, days: Int = 30) -> Decimal {
        guard accountType.hasMinimumPayment else { return 0 }
        
        let interest = monthlyInterest(on: balance, primeRate: primeRate, days: days)
        
        // 1% of balance + interest
        let percentOfBalance = minimumPaymentPercent ?? 0.01  // Default to 1%
        let calculated = (balance * percentOfBalance) + interest
        
        // Apply minimum floor
        let floor = minimumPaymentAmount ?? 40  // Default to $40
        let minimum = max(calculated, floor)
        
        // Can't pay more than the balance
        return min(minimum, balance)
    }
    
    // Credit utilization for credit cards
    func creditUtilization(balance: Decimal) -> Decimal? {
        guard accountType.hasCreditLimit,
              let limit = creditLimit,
              limit > 0 else { return nil }
        
        return (balance / limit) * 100
    }
    
    // Available credit for credit cards
    func availableCredit(balance: Decimal) -> Decimal? {
        guard accountType.hasCreditLimit,
              let limit = creditLimit else { return nil }
        
        return limit - balance
    }
}

@Model
final class BalanceEntry {
    var id: UUID
    var amount: Decimal  // Store as positive for all accounts
    var entryDate: Date  // When this balance was recorded
    var asOfDate: Date  // What date this balance represents
    
    // For credit cards: store available credit instead of balance for accuracy
    var availableCredit: Decimal?  // Only for credit card accounts
    
    // Relationship
    var account: Account?
    
    init(account: Account, amount: Decimal, asOfDate: Date = Date(), availableCredit: Decimal? = nil) {
        self.id = UUID()
        self.account = account
        self.amount = amount
        self.entryDate = Date()
        self.asOfDate = asOfDate
        self.availableCredit = availableCredit
    }
    
    // Computed property to get the effective balance
    func effectiveBalance() -> Decimal {
        guard let account = account else { return amount }
        
        // For credit cards, calculate balance from available credit if available
        if account.accountType == .creditCard,
           let available = availableCredit,
           let creditLimit = account.creditLimit {
            return creditLimit - available
        }
        
        return amount
    }
    
    // Computed property to get available credit for display
    func effectiveAvailableCredit() -> Decimal? {
        guard let account = account, 
              account.accountType == .creditCard else { return nil }
        
        // If we have stored available credit, use it
        if let available = availableCredit {
            return available
        }
        
        // Otherwise calculate from balance and credit limit
        if let creditLimit = account.creditLimit {
            return creditLimit - amount
        }
        
        return nil
    }
}

@Model
final class GlobalSettings {
    var id: UUID
    var currentPrimeRate: Decimal
    var lastUpdated: Date
    
    init(primeRate: Decimal = 8.5) {  // Current prime rate as of 2024
        self.id = UUID()
        self.currentPrimeRate = primeRate
        self.lastUpdated = Date()
    }
}

@Model
final class PaymentPlan {
    var id: UUID
    var generatedDate: Date
    var monthYear: String  // "January 2024"
    var totalAvailableForPayments: Decimal
    var strategyUsed: String  // "avalanche", "snowball", "custom"
    
    // Store the payment instructions
    @Relationship(deleteRule: .cascade) var payments: [PlannedPayment]?
    
    init() {
        self.id = UUID()
        self.generatedDate = Date()
        self.monthYear = DateFormatter.monthYear.string(from: Date())
        self.totalAvailableForPayments = 0
        self.strategyUsed = "manual"
    }
}

@Model
final class PlannedPayment {
    var id: UUID
    var account: Account?
    var suggestedAmount: Decimal
    var minimumAmount: Decimal
    var interest: Decimal  // Store calculated interest for reference
    var isCompleted: Bool
    
    init(account: Account, suggestedAmount: Decimal, minimumAmount: Decimal, interest: Decimal) {
        self.id = UUID()
        self.account = account
        self.suggestedAmount = suggestedAmount
        self.minimumAmount = minimumAmount
        self.interest = interest
        self.isCompleted = false
    }
}

// MARK: - Helper Extensions

extension DateFormatter {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

// MARK: - Aggregate Calculations

extension Array where Element == Account {
    // Total balance across all accounts
    func totalBalance(from balanceEntries: [BalanceEntry]) -> Decimal {
        return balanceEntries.reduce(0) { $0 + $1.amount }
    }
    
    // Total balance for credit cards only
    func totalCreditCardBalance(from balanceEntries: [BalanceEntry]) -> Decimal {
        let creditAccounts = self.filter { $0.accountType == .creditCard }
        let creditEntries = balanceEntries.filter { entry in
            creditAccounts.contains { $0.id == entry.account?.id }
        }
        return creditEntries.reduce(0) { $0 + $1.amount }
    }
    
    // Total available credit across all cards
    func totalAvailableCredit(from balanceEntries: [BalanceEntry]) -> Decimal {
        var total: Decimal = 0
        for account in self where account.accountType == .creditCard {
            if let entry = balanceEntries.first(where: { $0.account?.id == account.id }),
               let available = account.availableCredit(balance: entry.amount) {
                total += available
            }
        }
        return total
    }
    
    // Overall credit utilization
    func overallCreditUtilization(from balanceEntries: [BalanceEntry]) -> Decimal? {
        let totalLimit = self
            .filter { $0.accountType == .creditCard }
            .compactMap { $0.creditLimit }
            .reduce(0, +)
        
        guard totalLimit > 0 else { return nil }
        
        let totalBalance = totalCreditCardBalance(from: balanceEntries)
        return (totalBalance / totalLimit) * 100
    }
    
    // Total minimum payments
    func totalMinimumPayments(from balanceEntries: [BalanceEntry], primeRate: Decimal, days: Int = 30) -> Decimal {
        var total: Decimal = 0
        for account in self where account.accountType.hasMinimumPayment {
            if let entry = balanceEntries.first(where: { $0.account?.id == account.id }) {
                total += account.minimumPayment(balance: entry.amount, primeRate: primeRate, days: days)
            }
        }
        return total
    }
}
