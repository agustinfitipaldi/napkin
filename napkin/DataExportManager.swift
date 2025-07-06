//
//  DataExportManager.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/6/25.
//

import Foundation
import SwiftData

@MainActor
class DataExportManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Export Data
    
    func exportData(to url: URL) async throws {
        let napkinData = try await createExportData()
        try await writeDataToFile(napkinData, to: url)
    }
    
    private func createExportData() async throws -> NapkinDataExport {
        // Fetch all data from SwiftData
        let accountsDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.bankName), SortDescriptor(\.accountName)])
        let balanceEntriesDescriptor = FetchDescriptor<BalanceEntry>(sortBy: [SortDescriptor(\.entryDate, order: .reverse)])
        let subscriptionsDescriptor = FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)])
        let globalSettingsDescriptor = FetchDescriptor<GlobalSettings>()
        let paymentPlansDescriptor = FetchDescriptor<PaymentPlan>(sortBy: [SortDescriptor(\.generatedDate, order: .reverse)])
        let plannedPaymentsDescriptor = FetchDescriptor<PlannedPayment>()
        
        let accounts = try modelContext.fetch(accountsDescriptor)
        let balanceEntries = try modelContext.fetch(balanceEntriesDescriptor)
        let subscriptions = try modelContext.fetch(subscriptionsDescriptor)
        let globalSettings = try modelContext.fetch(globalSettingsDescriptor)
        let paymentPlans = try modelContext.fetch(paymentPlansDescriptor)
        _ = try modelContext.fetch(plannedPaymentsDescriptor) // Fetch for validation
        
        // Convert to DTOs
        let accountDTOs = accounts.map { AccountDTO(from: $0) }
        let balanceEntryDTOs = balanceEntries.map { BalanceEntryDTO(from: $0) }
        let subscriptionDTOs = subscriptions.map { SubscriptionDTO(from: $0) }
        let globalSettingsDTOs = globalSettings.map { GlobalSettingsDTO(from: $0) }
        let paymentPlanDTOs = paymentPlans.map { PaymentPlanDTO(from: $0) }
        
        // Handle planned payments with their payment plan relationships
        var plannedPaymentDTOs: [PlannedPaymentDTO] = []
        for paymentPlan in paymentPlans {
            if let payments = paymentPlan.payments {
                for payment in payments {
                    plannedPaymentDTOs.append(PlannedPaymentDTO(from: payment, paymentPlanId: paymentPlan.id))
                }
            }
        }
        
        return NapkinDataExport(
            accounts: accountDTOs,
            balanceEntries: balanceEntryDTOs,
            subscriptions: subscriptionDTOs,
            globalSettings: globalSettingsDTOs,
            paymentPlans: paymentPlanDTOs,
            plannedPayments: plannedPaymentDTOs
        )
    }
    
    private func writeDataToFile(_ data: NapkinDataExport, to url: URL) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(data)
        
        // Write to file
        let hasAccess = url.startAccessingSecurityScopedResource()
        do {
            try jsonData.write(to: url)
        } catch {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
            throw error
        }
        
        if hasAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: - Selective Export
    
    func exportAccounts(to url: URL) async throws {
        let accountsDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.bankName), SortDescriptor(\.accountName)])
        let accounts = try modelContext.fetch(accountsDescriptor)
        
        let accountDTOs = accounts.map { AccountDTO(from: $0) }
        let exportData = NapkinDataExport(accounts: accountDTOs)
        
        try await writeDataToFile(exportData, to: url)
    }
    
    func exportSubscriptions(to url: URL) async throws {
        let subscriptionsDescriptor = FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)])
        let subscriptions = try modelContext.fetch(subscriptionsDescriptor)
        
        let subscriptionDTOs = subscriptions.map { SubscriptionDTO(from: $0) }
        let exportData = NapkinDataExport(subscriptions: subscriptionDTOs)
        
        try await writeDataToFile(exportData, to: url)
    }
    
    func exportBalanceEntries(from startDate: Date, to endDate: Date, fileURL: URL) async throws {
        let balanceEntriesDescriptor = FetchDescriptor<BalanceEntry>(
            predicate: #Predicate { entry in
                entry.asOfDate >= startDate && entry.asOfDate <= endDate
            },
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        
        let balanceEntries = try modelContext.fetch(balanceEntriesDescriptor)
        let balanceEntryDTOs = balanceEntries.map { BalanceEntryDTO(from: $0) }
        
        let exportData = NapkinDataExport(balanceEntries: balanceEntryDTOs)
        try await writeDataToFile(exportData, to: fileURL)
    }
    
    // MARK: - Validation
    
    func validateExportData() throws -> ExportValidationResult {
        let accountsDescriptor = FetchDescriptor<Account>()
        let balanceEntriesDescriptor = FetchDescriptor<BalanceEntry>()
        let subscriptionsDescriptor = FetchDescriptor<Subscription>()
        
        let accounts = try modelContext.fetch(accountsDescriptor)
        let balanceEntries = try modelContext.fetch(balanceEntriesDescriptor)
        let subscriptions = try modelContext.fetch(subscriptionsDescriptor)
        
        var issues: [String] = []
        
        // Check for orphaned balance entries
        let accountIds = Set(accounts.map { $0.id })
        for balanceEntry in balanceEntries {
            if let accountId = balanceEntry.account?.id, !accountIds.contains(accountId) {
                issues.append("Balance entry \(balanceEntry.id) references non-existent account \(accountId)")
            }
        }
        
        // Check for invalid data
        for account in accounts {
            if account.bankName.isEmpty || account.accountName.isEmpty {
                issues.append("Account \(account.id) has empty bank name or account name")
            }
            
            if account.accountType.hasCreditLimit && account.creditLimit == nil {
                issues.append("Credit account \(account.id) missing credit limit")
            }
        }
        
        for subscription in subscriptions {
            if subscription.name.isEmpty {
                issues.append("Subscription \(subscription.id) has empty name")
            }
            
            if subscription.amount < 0 {
                issues.append("Subscription \(subscription.id) has negative amount")
            }
        }
        
        return ExportValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            accountCount: accounts.count,
            balanceEntryCount: balanceEntries.count,
            subscriptionCount: subscriptions.count
        )
    }
}

// MARK: - Validation Result

struct ExportValidationResult {
    let isValid: Bool
    let issues: [String]
    let accountCount: Int
    let balanceEntryCount: Int
    let subscriptionCount: Int
    
    var summary: String {
        if isValid {
            return "Export data is valid. Found \(accountCount) accounts, \(balanceEntryCount) balance entries, and \(subscriptionCount) subscriptions."
        } else {
            return "Export data has \(issues.count) issues:\n" + issues.joined(separator: "\n")
        }
    }
}