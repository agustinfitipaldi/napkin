//
//  QuickBalanceEntryView.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import SwiftData

struct QuickBalanceEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { $0.isActive }, sort: [SortDescriptor(\Account.bankName)])
    private var allActiveAccounts: [Account]
    
    @State private var balanceValues: [UUID: Decimal] = [:]
    @State private var balanceStrings: [UUID: String] = [:]
    @State private var availableCreditValues: [UUID: Decimal] = [:]
    @State private var availableCreditStrings: [UUID: String] = [:]
    @State private var asOfDate = Date()
    @State private var focusedAccountId: UUID?
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var hasAnyValidEntries: Bool {
        let hasBalanceEntries = balanceStrings.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasAvailableCreditEntries = availableCreditStrings.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return hasBalanceEntries || hasAvailableCreditEntries
    }
    
    private var activeAccounts: [Account] {
        return allActiveAccounts.sorted { first, second in
            if first.accountType != second.accountType {
                return first.accountType < second.accountType
            }
            return first.bankName < second.bankName
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .help("Cancel without saving changes (Esc)")
                
                Spacer()
                
                Text("Quick Balance Entry")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save All") {
                    saveAllBalances()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasAnyValidEntries)
                .buttonStyle(.borderedProminent)
                .help("Save all entered balances (⌘↩)")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            VStack(spacing: 0) {
                // Date selector
                HStack {
                    Text("As of Date:")
                        .font(.headline)
                    
                    DatePicker("As of Date", selection: $asOfDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    
                    Spacer()
                    
                    Button("Copy Last Month") {
                        copyLastMonthBalances()
                    }
                    .buttonStyle(.bordered)
                    .help("Copy balances from last month as starting values")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Balance entry form
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(activeAccounts) { account in
                            QuickBalanceRowView(
                                account: account,
                                value: Binding(
                                    get: { balanceValues[account.id] ?? 0 },
                                    set: { balanceValues[account.id] = $0 }
                                ),
                                stringValue: Binding(
                                    get: { balanceStrings[account.id] ?? "" },
                                    set: { balanceStrings[account.id] = $0 }
                                ),
                                availableCreditValue: Binding(
                                    get: { availableCreditValues[account.id] ?? 0 },
                                    set: { availableCreditValues[account.id] = $0 }
                                ),
                                availableCreditStringValue: Binding(
                                    get: { availableCreditStrings[account.id] ?? "" },
                                    set: { availableCreditStrings[account.id] = $0 }
                                ),
                                isFocused: focusedAccountId == account.id,
                                onFocusChange: { isFocused in
                                    if isFocused {
                                        focusedAccountId = account.id
                                    } else if focusedAccountId == account.id {
                                        focusedAccountId = nil
                                    }
                                }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            if account.id != activeAccounts.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadCurrentBalances()
        }
    }
    
    private func loadCurrentBalances() {
        // Load the most recent balance for each account
        for account in activeAccounts {
            if let latestBalance = account.balanceEntries?.sorted(by: { $0.entryDate > $1.entryDate }).first {
                if account.accountType == .creditCard {
                    if let availableCredit = latestBalance.availableCredit {
                        availableCreditValues[account.id] = availableCredit
                        availableCreditStrings[account.id] = formatDecimalForEditing(availableCredit)
                    } else if let creditLimit = account.creditLimit {
                        // Calculate available credit from balance
                        let availableCredit = creditLimit - latestBalance.amount
                        availableCreditValues[account.id] = availableCredit
                        availableCreditStrings[account.id] = formatDecimalForEditing(availableCredit)
                    }
                } else {
                    balanceValues[account.id] = latestBalance.amount
                    balanceStrings[account.id] = formatDecimalForEditing(latestBalance.amount)
                }
            }
        }
    }
    
    private func copyLastMonthBalances() {
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        
        for account in activeAccounts {
            // Find the balance entry closest to last month
            if let closestBalance = account.balanceEntries?
                .filter({ $0.asOfDate <= lastMonth })
                .sorted(by: { $0.asOfDate > $1.asOfDate })
                .first {
                
                if account.accountType == .creditCard {
                    if let availableCredit = closestBalance.effectiveAvailableCredit() {
                        availableCreditValues[account.id] = availableCredit
                        availableCreditStrings[account.id] = formatDecimalForEditing(availableCredit)
                    }
                } else {
                    balanceValues[account.id] = closestBalance.effectiveBalance()
                    balanceStrings[account.id] = formatDecimalForEditing(closestBalance.effectiveBalance())
                }
            }
        }
    }
    
    private func saveAllBalances() {
        guard hasAnyValidEntries else {
            dismiss()
            return
        }
        
        for account in activeAccounts {
            if account.accountType == .creditCard {
                // For credit cards, check available credit input
                if let stringValue = availableCreditStrings[account.id],
                   !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let availableCredit = availableCreditValues[account.id],
                   let creditLimit = account.creditLimit {
                    let calculatedBalance = creditLimit - availableCredit
                    let balanceEntry = BalanceEntry(account: account, amount: calculatedBalance, asOfDate: asOfDate, availableCredit: availableCredit)
                    modelContext.insert(balanceEntry)
                }
            } else {
                // For other accounts, check balance input
                if let stringValue = balanceStrings[account.id],
                   !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let value = balanceValues[account.id] {
                    let balanceEntry = BalanceEntry(account: account, amount: value, asOfDate: asOfDate)
                    modelContext.insert(balanceEntry)
                }
            }
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save balances: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct QuickBalanceRowView: View {
    let account: Account
    @Binding var value: Decimal
    @Binding var stringValue: String
    @Binding var availableCreditValue: Decimal
    @Binding var availableCreditStringValue: String
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Account info
            HStack(spacing: 12) {
                Image(systemName: iconForAccountType(account.accountType))
                    .foregroundColor(colorForAccountType(account.accountType))
                    .font(.title3)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.bankName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(account.accountName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Balance input
            VStack(alignment: .trailing, spacing: 4) {
                if account.accountType == .creditCard {
                    TextField("$0.00", text: $availableCreditStringValue)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .font(.title3)
                        .frame(width: 120)
                        .focused($isTextFieldFocused)
                        .onChange(of: availableCreditStringValue) { _, newValue in
                            if let decimal = parseDecimal(from: newValue) {
                                availableCreditValue = decimal
                                // Calculate balance from available credit
                                if let creditLimit = account.creditLimit {
                                    value = creditLimit - decimal
                                }
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            onFocusChange(focused)
                        }
                        .onSubmit {
                            focusNextAccount()
                        }
                } else {
                    TextField("$0.00", text: $stringValue)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .font(.title3)
                        .frame(width: 120)
                        .focused($isTextFieldFocused)
                        .onChange(of: stringValue) { _, newValue in
                            if let decimal = parseDecimal(from: newValue) {
                                value = decimal
                            }
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            onFocusChange(focused)
                        }
                        .onSubmit {
                            focusNextAccount()
                        }
                }
                
                // Balance type hint
                Text(balanceTypeHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .background(isFocused ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
    
    private var balanceTypeHint: String {
        switch account.accountType {
        case .creditCard:
            return "Available credit"
        case .loan, .mortgage:
            return "Amount owed"
        case .checking, .savings:
            return "Current balance"
        case .ira, .retirement401k, .brokerage:
            return "Account value"
        case .other:
            return "Balance"
        }
    }
    
    private func focusNextAccount() {
        // This could be enhanced to automatically move to the next field
        // For now, just clear focus
        isTextFieldFocused = false
    }
}

#Preview {
    QuickBalanceEntryView()
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}
