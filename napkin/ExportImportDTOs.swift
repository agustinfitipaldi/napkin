//
//  ExportImportDTOs.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/6/25.
//

import Foundation

// MARK: - Export/Import Container

struct NapkinDataExport: Codable {
    let metadata: ExportMetadata
    let accounts: [AccountDTO]
    let balanceEntries: [BalanceEntryDTO]
    let subscriptions: [SubscriptionDTO]
    let globalSettings: [GlobalSettingsDTO]
    let paymentPlans: [PaymentPlanDTO]
    let plannedPayments: [PlannedPaymentDTO]
    
    init(accounts: [AccountDTO] = [], balanceEntries: [BalanceEntryDTO] = [], subscriptions: [SubscriptionDTO] = [], globalSettings: [GlobalSettingsDTO] = [], paymentPlans: [PaymentPlanDTO] = [], plannedPayments: [PlannedPaymentDTO] = []) {
        self.metadata = ExportMetadata()
        self.accounts = accounts
        self.balanceEntries = balanceEntries
        self.subscriptions = subscriptions
        self.globalSettings = globalSettings
        self.paymentPlans = paymentPlans
        self.plannedPayments = plannedPayments
    }
}

struct ExportMetadata: Codable {
    let version: String
    let exportDate: Date
    let appVersion: String
    let schemaVersion: Int
    
    init() {
        self.version = "1.0"
        self.exportDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.schemaVersion = 1
    }
}

// MARK: - Account DTO

struct AccountDTO: Codable {
    let id: UUID
    let bankName: String
    let accountName: String
    let accountType: String
    let lastFourDigits: String?
    let creditLimit: Decimal?
    let aprType: String?
    let fixedAPR: Decimal?
    let marginAPR: Decimal?
    let maxAPR: Decimal?
    let paymentDueDay: Int?
    let minimumPaymentAmount: Decimal?
    let minimumPaymentPercent: Decimal?
    let lateFee: Decimal?
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    let notes: String?
    
    init(from account: Account) {
        self.id = account.id
        self.bankName = account.bankName
        self.accountName = account.accountName
        self.accountType = account.accountType.rawValue
        self.lastFourDigits = account.lastFourDigits
        self.creditLimit = account.creditLimit
        self.aprType = account.aprType?.rawValue
        self.fixedAPR = account.fixedAPR
        self.marginAPR = account.marginAPR
        self.maxAPR = account.maxAPR
        self.paymentDueDay = account.paymentDueDay
        self.minimumPaymentAmount = account.minimumPaymentAmount
        self.minimumPaymentPercent = account.minimumPaymentPercent
        self.lateFee = account.lateFee
        self.createdAt = account.createdAt
        self.updatedAt = account.updatedAt
        self.isActive = account.isActive
        self.notes = account.notes
    }
    
    func toAccount() -> Account {
        let account = Account(
            bankName: bankName,
            accountName: accountName,
            accountType: AccountType(rawValue: accountType) ?? .other
        )
        
        account.id = id
        account.lastFourDigits = lastFourDigits
        account.creditLimit = creditLimit
        account.aprType = aprType.flatMap { APRType(rawValue: $0) }
        account.fixedAPR = fixedAPR
        account.marginAPR = marginAPR
        account.maxAPR = maxAPR
        account.paymentDueDay = paymentDueDay
        account.minimumPaymentAmount = minimumPaymentAmount
        account.minimumPaymentPercent = minimumPaymentPercent
        account.lateFee = lateFee
        account.createdAt = createdAt
        account.updatedAt = updatedAt
        account.isActive = isActive
        account.notes = notes
        
        return account
    }
}

// MARK: - Balance Entry DTO

struct BalanceEntryDTO: Codable {
    let id: UUID
    let accountId: UUID
    let amount: Decimal
    let entryDate: Date
    let asOfDate: Date
    let availableCredit: Decimal?
    
    init(from balanceEntry: BalanceEntry) {
        self.id = balanceEntry.id
        self.accountId = balanceEntry.account?.id ?? UUID()
        self.amount = balanceEntry.amount
        self.entryDate = balanceEntry.entryDate
        self.asOfDate = balanceEntry.asOfDate
        self.availableCredit = balanceEntry.availableCredit
    }
    
    func toBalanceEntry(account: Account) -> BalanceEntry {
        let balanceEntry = BalanceEntry(
            account: account,
            amount: amount,
            asOfDate: asOfDate,
            availableCredit: availableCredit
        )
        
        balanceEntry.id = id
        balanceEntry.entryDate = entryDate
        
        return balanceEntry
    }
}

// MARK: - Subscription DTO

struct SubscriptionDTO: Codable {
    let id: UUID
    let name: String
    let amount: Decimal
    let timesPerYear: Int
    let category: String
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(from subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.amount = subscription.amount
        self.timesPerYear = subscription.timesPerYear
        self.category = subscription.category.rawValue
        self.notes = subscription.notes
        self.isActive = subscription.isActive
        self.createdAt = subscription.createdAt
        self.updatedAt = subscription.updatedAt
    }
    
    func toSubscription() -> Subscription {
        let subscription = Subscription(
            name: name,
            amount: amount,
            timesPerYear: timesPerYear,
            category: SubscriptionCategory(rawValue: category) ?? .other,
            notes: notes
        )
        
        subscription.id = id
        subscription.isActive = isActive
        subscription.createdAt = createdAt
        subscription.updatedAt = updatedAt
        
        return subscription
    }
}

// MARK: - Global Settings DTO

struct GlobalSettingsDTO: Codable {
    let id: UUID
    let currentPrimeRate: Decimal
    let lastUpdated: Date
    
    init(from globalSettings: GlobalSettings) {
        self.id = globalSettings.id
        self.currentPrimeRate = globalSettings.currentPrimeRate
        self.lastUpdated = globalSettings.lastUpdated
    }
    
    func toGlobalSettings() -> GlobalSettings {
        let settings = GlobalSettings(primeRate: currentPrimeRate)
        settings.id = id
        settings.lastUpdated = lastUpdated
        return settings
    }
}

// MARK: - Payment Plan DTO

struct PaymentPlanDTO: Codable {
    let id: UUID
    let generatedDate: Date
    let monthYear: String
    let totalAvailableForPayments: Decimal
    let strategyUsed: String
    
    init(from paymentPlan: PaymentPlan) {
        self.id = paymentPlan.id
        self.generatedDate = paymentPlan.generatedDate
        self.monthYear = paymentPlan.monthYear
        self.totalAvailableForPayments = paymentPlan.totalAvailableForPayments
        self.strategyUsed = paymentPlan.strategyUsed
    }
    
    func toPaymentPlan() -> PaymentPlan {
        let paymentPlan = PaymentPlan()
        paymentPlan.id = id
        paymentPlan.generatedDate = generatedDate
        paymentPlan.monthYear = monthYear
        paymentPlan.totalAvailableForPayments = totalAvailableForPayments
        paymentPlan.strategyUsed = strategyUsed
        return paymentPlan
    }
}

// MARK: - Planned Payment DTO

struct PlannedPaymentDTO: Codable {
    let id: UUID
    let accountId: UUID
    let paymentPlanId: UUID
    let suggestedAmount: Decimal
    let minimumAmount: Decimal
    let interest: Decimal
    let isCompleted: Bool
    
    init(from plannedPayment: PlannedPayment, paymentPlanId: UUID) {
        self.id = plannedPayment.id
        self.accountId = plannedPayment.account?.id ?? UUID()
        self.paymentPlanId = paymentPlanId
        self.suggestedAmount = plannedPayment.suggestedAmount
        self.minimumAmount = plannedPayment.minimumAmount
        self.interest = plannedPayment.interest
        self.isCompleted = plannedPayment.isCompleted
    }
    
    func toPlannedPayment(account: Account) -> PlannedPayment {
        let plannedPayment = PlannedPayment(
            account: account,
            suggestedAmount: suggestedAmount,
            minimumAmount: minimumAmount,
            interest: interest
        )
        
        plannedPayment.id = id
        plannedPayment.isCompleted = isCompleted
        
        return plannedPayment
    }
}

// MARK: - Custom Decimal Coding
// Note: Decimal is already Codable in newer Swift versions
// This extension is kept for compatibility if needed

// MARK: - Import Result

struct ImportResult {
    let accountsImported: Int
    let balanceEntriesImported: Int
    let subscriptionsImported: Int
    let globalSettingsImported: Int
    let paymentPlansImported: Int
    let plannedPaymentsImported: Int
    
    var totalItemsImported: Int {
        accountsImported + balanceEntriesImported + subscriptionsImported + globalSettingsImported + paymentPlansImported + plannedPaymentsImported
    }
}