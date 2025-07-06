//
//  DataImportManager.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/6/25.
//

import Foundation
import SwiftData

@MainActor
class DataImportManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Import Data
    
    func importData(from url: URL, mergeStrategy: ImportMergeStrategy = .merge) async throws -> ImportResult {
        let napkinData = try await readDataFromFile(url)
        try validateImportData(napkinData)
        
        // Create backup before import
        try await createBackup()
        
        return try await importValidatedData(napkinData, mergeStrategy: mergeStrategy)
    }
    
    private func readDataFromFile(_ url: URL) async throws -> NapkinDataExport {
        let hasAccess = url.startAccessingSecurityScopedResource()
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let result = try decoder.decode(NapkinDataExport.self, from: data)
            
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
            
            return result
        } catch {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
            throw error
        }
    }
    
    private func validateImportData(_ data: NapkinDataExport) throws {
        // Check schema version compatibility
        if data.metadata.schemaVersion > 1 {
            throw ImportError.incompatibleVersion("Import file requires a newer version of the app")
        }
        
        // Validate data integrity
        let accountIds = Set(data.accounts.map { $0.id })
        
        // Check balance entry references
        for balanceEntry in data.balanceEntries {
            if !accountIds.contains(balanceEntry.accountId) {
                throw ImportError.invalidData("Balance entry \(balanceEntry.id) references non-existent account \(balanceEntry.accountId)")
            }
        }
        
        // Check planned payment references
        let paymentPlanIds = Set(data.paymentPlans.map { $0.id })
        for plannedPayment in data.plannedPayments {
            if !paymentPlanIds.contains(plannedPayment.paymentPlanId) {
                throw ImportError.invalidData("Planned payment \(plannedPayment.id) references non-existent payment plan \(plannedPayment.paymentPlanId)")
            }
            
            if !accountIds.contains(plannedPayment.accountId) {
                throw ImportError.invalidData("Planned payment \(plannedPayment.id) references non-existent account \(plannedPayment.accountId)")
            }
        }
        
        // Validate account types and enums
        for account in data.accounts {
            if AccountType(rawValue: account.accountType) == nil {
                throw ImportError.invalidData("Account \(account.id) has invalid account type: \(account.accountType)")
            }
            
            if let aprType = account.aprType, APRType(rawValue: aprType) == nil {
                throw ImportError.invalidData("Account \(account.id) has invalid APR type: \(aprType)")
            }
        }
        
        // Validate subscription categories
        for subscription in data.subscriptions {
            if SubscriptionCategory(rawValue: subscription.category) == nil {
                throw ImportError.invalidData("Subscription \(subscription.id) has invalid category: \(subscription.category)")
            }
        }
    }
    
    private func importValidatedData(_ data: NapkinDataExport, mergeStrategy: ImportMergeStrategy) async throws -> ImportResult {
        var result = ImportResult(
            accountsImported: 0,
            balanceEntriesImported: 0,
            subscriptionsImported: 0,
            globalSettingsImported: 0,
            paymentPlansImported: 0,
            plannedPaymentsImported: 0
        )
        
        try modelContext.transaction {
            // Import accounts first (base entities)
            let importedAccounts = try importAccounts(data.accounts, mergeStrategy: mergeStrategy)
            result = ImportResult(
                accountsImported: importedAccounts.count,
                balanceEntriesImported: result.balanceEntriesImported,
                subscriptionsImported: result.subscriptionsImported,
                globalSettingsImported: result.globalSettingsImported,
                paymentPlansImported: result.paymentPlansImported,
                plannedPaymentsImported: result.plannedPaymentsImported
            )
            
            // Import balance entries (depend on accounts)
            let importedBalanceEntries = try importBalanceEntries(data.balanceEntries, accounts: importedAccounts, mergeStrategy: mergeStrategy)
            result = ImportResult(
                accountsImported: result.accountsImported,
                balanceEntriesImported: importedBalanceEntries.count,
                subscriptionsImported: result.subscriptionsImported,
                globalSettingsImported: result.globalSettingsImported,
                paymentPlansImported: result.paymentPlansImported,
                plannedPaymentsImported: result.plannedPaymentsImported
            )
            
            // Import subscriptions (independent)
            let importedSubscriptions = try importSubscriptions(data.subscriptions, mergeStrategy: mergeStrategy)
            result = ImportResult(
                accountsImported: result.accountsImported,
                balanceEntriesImported: result.balanceEntriesImported,
                subscriptionsImported: importedSubscriptions.count,
                globalSettingsImported: result.globalSettingsImported,
                paymentPlansImported: result.paymentPlansImported,
                plannedPaymentsImported: result.plannedPaymentsImported
            )
            
            // Import global settings
            let importedGlobalSettings = try importGlobalSettings(data.globalSettings, mergeStrategy: mergeStrategy)
            result = ImportResult(
                accountsImported: result.accountsImported,
                balanceEntriesImported: result.balanceEntriesImported,
                subscriptionsImported: result.subscriptionsImported,
                globalSettingsImported: importedGlobalSettings.count,
                paymentPlansImported: result.paymentPlansImported,
                plannedPaymentsImported: result.plannedPaymentsImported
            )
            
            // Import payment plans and planned payments
            let (importedPaymentPlans, importedPlannedPayments) = try importPaymentPlansAndPayments(
                data.paymentPlans,
                data.plannedPayments,
                accounts: importedAccounts,
                mergeStrategy: mergeStrategy
            )
            result = ImportResult(
                accountsImported: result.accountsImported,
                balanceEntriesImported: result.balanceEntriesImported,
                subscriptionsImported: result.subscriptionsImported,
                globalSettingsImported: result.globalSettingsImported,
                paymentPlansImported: importedPaymentPlans.count,
                plannedPaymentsImported: importedPlannedPayments.count
            )
        }
        
        try modelContext.save()
        return result
    }
    
    // MARK: - Import Individual Entity Types
    
    private func importAccounts(_ accountDTOs: [AccountDTO], mergeStrategy: ImportMergeStrategy) throws -> [Account] {
        var importedAccounts: [Account] = []
        
        let existingAccountsDescriptor = FetchDescriptor<Account>()
        let existingAccounts = try modelContext.fetch(existingAccountsDescriptor)
        let existingAccountsById = Dictionary(uniqueKeysWithValues: existingAccounts.map { ($0.id, $0) })
        
        for accountDTO in accountDTOs {
            if let existingAccount = existingAccountsById[accountDTO.id] {
                switch mergeStrategy {
                case .merge:
                    updateAccount(existingAccount, with: accountDTO)
                    importedAccounts.append(existingAccount)
                case .replace:
                    modelContext.delete(existingAccount)
                    let newAccount = accountDTO.toAccount()
                    modelContext.insert(newAccount)
                    importedAccounts.append(newAccount)
                case .skip:
                    importedAccounts.append(existingAccount)
                }
            } else {
                let newAccount = accountDTO.toAccount()
                modelContext.insert(newAccount)
                importedAccounts.append(newAccount)
            }
        }
        
        return importedAccounts
    }
    
    private func importBalanceEntries(_ balanceEntryDTOs: [BalanceEntryDTO], accounts: [Account], mergeStrategy: ImportMergeStrategy) throws -> [BalanceEntry] {
        var importedBalanceEntries: [BalanceEntry] = []
        
        let existingBalanceEntriesDescriptor = FetchDescriptor<BalanceEntry>()
        let existingBalanceEntries = try modelContext.fetch(existingBalanceEntriesDescriptor)
        let existingBalanceEntriesById = Dictionary(uniqueKeysWithValues: existingBalanceEntries.map { ($0.id, $0) })
        
        let accountsById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        
        for balanceEntryDTO in balanceEntryDTOs {
            guard let account = accountsById[balanceEntryDTO.accountId] else {
                continue // Skip if account not found
            }
            
            if let existingBalanceEntry = existingBalanceEntriesById[balanceEntryDTO.id] {
                switch mergeStrategy {
                case .merge:
                    updateBalanceEntry(existingBalanceEntry, with: balanceEntryDTO, account: account)
                    importedBalanceEntries.append(existingBalanceEntry)
                case .replace:
                    modelContext.delete(existingBalanceEntry)
                    let newBalanceEntry = balanceEntryDTO.toBalanceEntry(account: account)
                    modelContext.insert(newBalanceEntry)
                    importedBalanceEntries.append(newBalanceEntry)
                case .skip:
                    importedBalanceEntries.append(existingBalanceEntry)
                }
            } else {
                let newBalanceEntry = balanceEntryDTO.toBalanceEntry(account: account)
                modelContext.insert(newBalanceEntry)
                importedBalanceEntries.append(newBalanceEntry)
            }
        }
        
        return importedBalanceEntries
    }
    
    private func importSubscriptions(_ subscriptionDTOs: [SubscriptionDTO], mergeStrategy: ImportMergeStrategy) throws -> [Subscription] {
        var importedSubscriptions: [Subscription] = []
        
        let existingSubscriptionsDescriptor = FetchDescriptor<Subscription>()
        let existingSubscriptions = try modelContext.fetch(existingSubscriptionsDescriptor)
        let existingSubscriptionsById = Dictionary(uniqueKeysWithValues: existingSubscriptions.map { ($0.id, $0) })
        
        for subscriptionDTO in subscriptionDTOs {
            if let existingSubscription = existingSubscriptionsById[subscriptionDTO.id] {
                switch mergeStrategy {
                case .merge:
                    updateSubscription(existingSubscription, with: subscriptionDTO)
                    importedSubscriptions.append(existingSubscription)
                case .replace:
                    modelContext.delete(existingSubscription)
                    let newSubscription = subscriptionDTO.toSubscription()
                    modelContext.insert(newSubscription)
                    importedSubscriptions.append(newSubscription)
                case .skip:
                    importedSubscriptions.append(existingSubscription)
                }
            } else {
                let newSubscription = subscriptionDTO.toSubscription()
                modelContext.insert(newSubscription)
                importedSubscriptions.append(newSubscription)
            }
        }
        
        return importedSubscriptions
    }
    
    private func importGlobalSettings(_ globalSettingsDTOs: [GlobalSettingsDTO], mergeStrategy: ImportMergeStrategy) throws -> [GlobalSettings] {
        var importedGlobalSettings: [GlobalSettings] = []
        
        let existingGlobalSettingsDescriptor = FetchDescriptor<GlobalSettings>()
        let existingGlobalSettings = try modelContext.fetch(existingGlobalSettingsDescriptor)
        let existingGlobalSettingsById = Dictionary(uniqueKeysWithValues: existingGlobalSettings.map { ($0.id, $0) })
        
        for globalSettingsDTO in globalSettingsDTOs {
            if let existingGlobalSettings = existingGlobalSettingsById[globalSettingsDTO.id] {
                switch mergeStrategy {
                case .merge:
                    updateGlobalSettings(existingGlobalSettings, with: globalSettingsDTO)
                    importedGlobalSettings.append(existingGlobalSettings)
                case .replace:
                    modelContext.delete(existingGlobalSettings)
                    let newGlobalSettings = globalSettingsDTO.toGlobalSettings()
                    modelContext.insert(newGlobalSettings)
                    importedGlobalSettings.append(newGlobalSettings)
                case .skip:
                    importedGlobalSettings.append(existingGlobalSettings)
                }
            } else {
                let newGlobalSettings = globalSettingsDTO.toGlobalSettings()
                modelContext.insert(newGlobalSettings)
                importedGlobalSettings.append(newGlobalSettings)
            }
        }
        
        return importedGlobalSettings
    }
    
    private func importPaymentPlansAndPayments(
        _ paymentPlanDTOs: [PaymentPlanDTO],
        _ plannedPaymentDTOs: [PlannedPaymentDTO],
        accounts: [Account],
        mergeStrategy: ImportMergeStrategy
    ) throws -> ([PaymentPlan], [PlannedPayment]) {
        var importedPaymentPlans: [PaymentPlan] = []
        var importedPlannedPayments: [PlannedPayment] = []
        
        let existingPaymentPlansDescriptor = FetchDescriptor<PaymentPlan>()
        let existingPaymentPlans = try modelContext.fetch(existingPaymentPlansDescriptor)
        let existingPaymentPlansById = Dictionary(uniqueKeysWithValues: existingPaymentPlans.map { ($0.id, $0) })
        
        let accountsById = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        
        // Import payment plans first
        for paymentPlanDTO in paymentPlanDTOs {
            if let existingPaymentPlan = existingPaymentPlansById[paymentPlanDTO.id] {
                switch mergeStrategy {
                case .merge, .replace:
                    updatePaymentPlan(existingPaymentPlan, with: paymentPlanDTO)
                    importedPaymentPlans.append(existingPaymentPlan)
                case .skip:
                    importedPaymentPlans.append(existingPaymentPlan)
                }
            } else {
                let newPaymentPlan = paymentPlanDTO.toPaymentPlan()
                modelContext.insert(newPaymentPlan)
                importedPaymentPlans.append(newPaymentPlan)
            }
        }
        
        // Import planned payments
        let paymentPlansById = Dictionary(uniqueKeysWithValues: importedPaymentPlans.map { ($0.id, $0) })
        
        for plannedPaymentDTO in plannedPaymentDTOs {
            guard let account = accountsById[plannedPaymentDTO.accountId],
                  let paymentPlan = paymentPlansById[plannedPaymentDTO.paymentPlanId] else {
                continue
            }
            
            let newPlannedPayment = plannedPaymentDTO.toPlannedPayment(account: account)
            modelContext.insert(newPlannedPayment)
            
            // Add to payment plan's relationship
            if paymentPlan.payments == nil {
                paymentPlan.payments = []
            }
            paymentPlan.payments?.append(newPlannedPayment)
            
            importedPlannedPayments.append(newPlannedPayment)
        }
        
        return (importedPaymentPlans, importedPlannedPayments)
    }
    
    // MARK: - Update Helpers
    
    private func updateAccount(_ account: Account, with dto: AccountDTO) {
        account.bankName = dto.bankName
        account.accountName = dto.accountName
        account.accountType = AccountType(rawValue: dto.accountType) ?? account.accountType
        account.lastFourDigits = dto.lastFourDigits
        account.creditLimit = dto.creditLimit
        account.aprType = dto.aprType.flatMap { APRType(rawValue: $0) }
        account.fixedAPR = dto.fixedAPR
        account.marginAPR = dto.marginAPR
        account.maxAPR = dto.maxAPR
        account.paymentDueDay = dto.paymentDueDay
        account.minimumPaymentAmount = dto.minimumPaymentAmount
        account.minimumPaymentPercent = dto.minimumPaymentPercent
        account.lateFee = dto.lateFee
        account.isActive = dto.isActive
        account.notes = dto.notes
        account.updatedAt = Date()
    }
    
    private func updateBalanceEntry(_ balanceEntry: BalanceEntry, with dto: BalanceEntryDTO, account: Account) {
        balanceEntry.account = account
        balanceEntry.amount = dto.amount
        balanceEntry.asOfDate = dto.asOfDate
        balanceEntry.availableCredit = dto.availableCredit
    }
    
    private func updateSubscription(_ subscription: Subscription, with dto: SubscriptionDTO) {
        subscription.name = dto.name
        subscription.amount = dto.amount
        subscription.timesPerYear = dto.timesPerYear
        subscription.category = SubscriptionCategory(rawValue: dto.category) ?? subscription.category
        subscription.notes = dto.notes
        subscription.isActive = dto.isActive
        subscription.updatedAt = Date()
    }
    
    private func updateGlobalSettings(_ globalSettings: GlobalSettings, with dto: GlobalSettingsDTO) {
        globalSettings.currentPrimeRate = dto.currentPrimeRate
        globalSettings.lastUpdated = Date()
    }
    
    private func updatePaymentPlan(_ paymentPlan: PaymentPlan, with dto: PaymentPlanDTO) {
        paymentPlan.monthYear = dto.monthYear
        paymentPlan.totalAvailableForPayments = dto.totalAvailableForPayments
        paymentPlan.strategyUsed = dto.strategyUsed
    }
    
    // MARK: - Backup
    
    private func createBackup() async throws {
        let documentsURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let backupURL = documentsURL.appendingPathComponent("napkin-backup-\(DateFormatter.exportFilename.string(from: Date())).json")
        
        let exportManager = DataExportManager(modelContext: modelContext)
        try await exportManager.exportData(to: backupURL)
    }
}

// MARK: - Supporting Types

enum ImportMergeStrategy {
    case merge      // Update existing items with new data
    case replace    // Delete existing items and create new ones
    case skip       // Keep existing items, don't import duplicates
}

enum ImportError: LocalizedError {
    case incompatibleVersion(String)
    case invalidData(String)
    case fileNotFound
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let message):
            return "Incompatible version: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .fileNotFound:
            return "Import file not found"
        case .corruptedData:
            return "Import file appears to be corrupted"
        }
    }
}