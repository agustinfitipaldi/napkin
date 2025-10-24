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

enum SubscriptionCategory: String, Codable, CaseIterable, Comparable {
    case entertainment = "Entertainment"
    case productivity = "Productivity"
    case essentials = "Essentials"
    case utilities = "Utilities"
    case insurance = "Insurance"
    case fitness = "Fitness & Health"
    case education = "Education"
    case news = "News & Media"
    case gaming = "Gaming"
    case domains = "Domains"
    case other = "Other"
    
    var systemImage: String {
        switch self {
        case .entertainment: return "tv"
        case .productivity: return "laptopcomputer"
        case .essentials: return "star.fill"
        case .utilities: return "house"
        case .insurance: return "shield"
        case .fitness: return "heart"
        case .education: return "book"
        case .news: return "newspaper"
        case .gaming: return "gamecontroller"
        case .domains: return "globe"
        case .other: return "folder"
        }
    }
    
    var color: String {
        switch self {
        case .entertainment: return "purple"
        case .productivity: return "blue"
        case .essentials: return "yellow"
        case .utilities: return "orange"
        case .insurance: return "green"
        case .fitness: return "red"
        case .education: return "indigo"
        case .news: return "brown"
        case .gaming: return "pink"
        case .domains: return "cyan"
        case .other: return "secondary"
        }
    }
    
    static func < (lhs: SubscriptionCategory, rhs: SubscriptionCategory) -> Bool {
        let order: [SubscriptionCategory] = [.essentials, .entertainment, .productivity, .utilities, .insurance, .fitness, .education, .news, .gaming, .domains, .other]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Models

@Model
final class Account {
    var id: UUID = UUID()
    var bankName: String = ""
    var accountName: String = ""
    var accountType: AccountType = .checking
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
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isActive: Bool = true  // For soft delete/archive
    var notes: String?

    // Relationships
    @Relationship(deleteRule: .cascade) var balanceEntries: [BalanceEntry]?
    @Relationship(inverse: \PlannedPayment.account) var plannedPayments: [PlannedPayment]?
    
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
    
    // Calculate next due date from a given date
    func nextDueDate(from date: Date = Date()) -> Date? {
        guard let paymentDueDay = paymentDueDay else { return nil }
        
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: date)
        
        // If we haven't passed this month's due date, return it
        if currentDay <= paymentDueDay {
            return calendar.date(bySetting: .day, value: paymentDueDay, of: date) ?? date
        } else {
            // Otherwise, return next month's due date
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) ?? date
            return calendar.date(bySetting: .day, value: paymentDueDay, of: nextMonth) ?? date
        }
    }
    
    // Check if payment is due between two dates
    func isDueBetween(startDate: Date, endDate: Date) -> Bool {
        guard let dueDate = nextDueDate(from: startDate) else { return false }
        return dueDate >= startDate && dueDate <= endDate
    }
}

@Model
final class BalanceEntry {
    var id: UUID = UUID()
    var amount: Decimal = 0  // Store as positive for all accounts
    var entryDate: Date = Date()  // When this balance was recorded
    var asOfDate: Date = Date()  // What date this balance represents

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
    var id: UUID = UUID()
    var currentPrimeRate: Decimal = 8.5
    var lastUpdated: Date = Date()
    
    init(primeRate: Decimal = 8.5) {  // Current prime rate as of 2024
        self.id = UUID()
        self.currentPrimeRate = primeRate
        self.lastUpdated = Date()
    }
}

@Model
final class PaymentPlan {
    var id: UUID = UUID()
    var generatedDate: Date = Date()
    var monthYear: String = ""  // "January 2024"
    var totalAvailableForPayments: Decimal = 0
    var strategyUsed: String = "manual"  // "avalanche", "snowball", "custom"

    // Store the payment instructions
    @Relationship(deleteRule: .cascade, inverse: \PlannedPayment.paymentPlan) var payments: [PlannedPayment]?
    
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
    var id: UUID = UUID()
    var suggestedAmount: Decimal = 0
    var minimumAmount: Decimal = 0
    var interest: Decimal = 0  // Store calculated interest for reference
    var isCompleted: Bool = false

    // Relationships
    var account: Account?
    var paymentPlan: PaymentPlan?
    
    init(account: Account, suggestedAmount: Decimal, minimumAmount: Decimal, interest: Decimal) {
        self.id = UUID()
        self.account = account
        self.suggestedAmount = suggestedAmount
        self.minimumAmount = minimumAmount
        self.interest = interest
        self.isCompleted = false
    }
}

@Model
final class Subscription {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Decimal = 0  // Amount paid per frequency period
    var timesPerYear: Int = 12  // How many times this amount is paid per year
    var category: SubscriptionCategory = .other
    var notes: String?
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(name: String, amount: Decimal, timesPerYear: Int, category: SubscriptionCategory, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.timesPerYear = max(1, min(365, timesPerYear))  // Clamp between 1 and 365
        self.category = category
        self.notes = notes
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Calculate annual cost
    var annualCost: Decimal {
        return amount * Decimal(timesPerYear)
    }
    
    // Calculate monthly cost
    var monthlyCost: Decimal {
        return annualCost / 12
    }
    
    // Calculate weekly cost
    var weeklyCost: Decimal {
        return annualCost / 52
    }
    
    // Calculate daily cost
    var dailyCost: Decimal {
        return annualCost / 365
    }
    
    // Friendly frequency description
    var frequencyDescription: String {
        switch timesPerYear {
        case 1: return "Annually"
        case 2: return "Semi-annually"
        case 4: return "Quarterly"
        case 12: return "Monthly"
        case 24: return "Bi-monthly"
        case 26: return "Bi-weekly"
        case 52: return "Weekly"
        case 365: return "Daily"
        default: return "\(timesPerYear) times per year"
        }
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

// MARK: - Subscription Aggregate Calculations

extension Array where Element == Subscription {
    // Total monthly cost across all active subscriptions
    func totalMonthlyCost() -> Decimal {
        return self.filter { $0.isActive }
            .reduce(0) { $0 + $1.monthlyCost }
    }
    
    // Total annual cost across all active subscriptions
    func totalAnnualCost() -> Decimal {
        return self.filter { $0.isActive }
            .reduce(0) { $0 + $1.annualCost }
    }
    
    // Total monthly cost by category
    func totalMonthlyCost(for category: SubscriptionCategory) -> Decimal {
        return self.filter { $0.isActive && $0.category == category }
            .reduce(0) { $0 + $1.monthlyCost }
    }
    
    // Group subscriptions by category
    func groupedByCategory() -> [SubscriptionCategory: [Subscription]] {
        let activeSubscriptions = self.filter { $0.isActive }
        return Dictionary(grouping: activeSubscriptions) { $0.category }
    }
    
    // Get most expensive subscription
    func mostExpensive() -> Subscription? {
        return self.filter { $0.isActive }
            .max { $0.monthlyCost < $1.monthlyCost }
    }
}

// MARK: - Paycheck Configuration

@Model
final class PaycheckConfig {
    var id: UUID = UUID()
    var expectedAmount: Decimal = 0
    var nextPaycheckDate: Date = Date()
    var frequency: PaycheckFrequency = .biweekly
    var isActive: Bool = true
    var notes: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(expectedAmount: Decimal, nextPaycheckDate: Date, frequency: PaycheckFrequency, notes: String? = nil) {
        self.id = UUID()
        self.expectedAmount = expectedAmount
        self.nextPaycheckDate = nextPaycheckDate
        self.frequency = frequency
        self.isActive = true
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Calculate the paycheck date after the given date
    func nextPaycheckAfter(_ date: Date) -> Date {
        let calendar = Calendar.current
        let currentNext = nextPaycheckDate
        
        // If the configured next paycheck is after the given date, return it
        if currentNext > date {
            return currentNext
        }
        
        // Otherwise calculate based on frequency
        switch frequency {
        case .weekly:
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: currentNext, to: date).weekOfYear ?? 0
            let additionalWeeks = weeksDiff + 1
            return calendar.date(byAdding: .weekOfYear, value: additionalWeeks, to: currentNext) ?? currentNext
            
        case .biweekly:
            let weeksDiff = calendar.dateComponents([.weekOfYear], from: currentNext, to: date).weekOfYear ?? 0
            let additionalBiweeks = ((weeksDiff / 2) + 1) * 2
            return calendar.date(byAdding: .weekOfYear, value: additionalBiweeks, to: currentNext) ?? currentNext
            
        case .monthly:
            let monthsDiff = calendar.dateComponents([.month], from: currentNext, to: date).month ?? 0
            let additionalMonths = monthsDiff + 1
            return calendar.date(byAdding: .month, value: additionalMonths, to: currentNext) ?? currentNext
        }
    }
    
    // Calculate expected amount for shortfall protection (could be different from expectedAmount)
    func expectedAmountForDate(_ date: Date) -> Decimal {
        // For now, return the configured amount
        // In the future, this could factor in overtime, reduced hours, etc.
        return expectedAmount
    }
}

enum PaycheckFrequency: String, CaseIterable, Codable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly" 
    case monthly = "Monthly"
    
    var systemImage: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }
}
