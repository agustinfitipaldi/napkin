//
//  BalanceEntryView.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import SwiftData

struct BalanceEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let account: Account
    let balanceEntry: BalanceEntry?
    
    @State private var amount: Decimal = 0
    @State private var amountString = ""
    @State private var availableCredit: Decimal = 0
    @State private var availableCreditString = ""
    @State private var asOfDate = Date()
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isEditing: Bool {
        balanceEntry != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text(isEditing ? "Edit Balance" : "Add Balance")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    saveBalance()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Account info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: iconForAccountType(account.accountType))
                                .foregroundColor(colorForAccountType(account.accountType))
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.bankName)
                                    .font(.headline)
                                Text(account.accountName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Balance entry
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Balance Information")
                            .font(.headline)
                        
                        if account.accountType == .creditCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available Credit")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("$0.00", text: $availableCreditString)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.leading)
                                    .font(.title2)
                                    .onChange(of: availableCreditString) { _, newValue in
                                        if let decimal = parseDecimal(from: newValue) {
                                            availableCredit = decimal
                                            // Calculate balance from available credit
                                            if let creditLimit = account.creditLimit {
                                                amount = creditLimit - decimal
                                            }
                                        }
                                    }
                            }
                            
                            // Show calculated balance
                            if let creditLimit = account.creditLimit, availableCredit > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Calculated Balance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(creditLimit - availableCredit))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(balanceLabel)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextField("$0.00", text: $amountString)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.leading)
                                    .font(.title2)
                                    .onChange(of: amountString) { _, newValue in
                                        if let decimal = parseDecimal(from: newValue) {
                                            amount = decimal
                                        }
                                    }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As of Date")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            DatePicker("As of Date", selection: $asOfDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        
                        // Balance hint
                        Text(balanceHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, maxWidth: 500, minHeight: 300)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadBalanceData()
        }
    }
    
    private var balanceLabel: String {
        switch account.accountType {
        case .creditCard, .loan, .mortgage:
            return "Outstanding Balance"
        case .checking, .savings:
            return "Current Balance"
        case .ira, .retirement401k, .brokerage:
            return "Account Value"
        case .other:
            return "Balance"
        }
    }
    
    private var balanceHint: String {
        switch account.accountType {
        case .creditCard:
            return "Enter your available credit (the amount you can still spend). This is more accurate than the statement balance since it reflects pending transactions."
        case .loan, .mortgage:
            return "Enter the remaining balance on this loan."
        case .checking, .savings:
            return "Enter your current account balance. Use negative numbers if overdrawn."
        case .ira, .retirement401k, .brokerage:
            return "Enter the current value of your account."
        case .other:
            return "Enter the current balance or value."
        }
    }
    
    private var isFormValid: Bool {
        if account.accountType == .creditCard {
            return availableCredit >= 0 && !availableCreditString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return amount >= 0 && !amountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func loadBalanceData() {
        guard let balanceEntry = balanceEntry else { return }
        
        amount = balanceEntry.amount
        asOfDate = balanceEntry.asOfDate
        
        if account.accountType == .creditCard {
            if let storedAvailableCredit = balanceEntry.availableCredit {
                availableCredit = storedAvailableCredit
                availableCreditString = formatDecimalForEditing(storedAvailableCredit)
            } else if let creditLimit = account.creditLimit {
                // Calculate available credit from balance
                availableCredit = creditLimit - amount
                availableCreditString = formatDecimalForEditing(availableCredit)
            }
        } else {
            amountString = formatDecimalForEditing(amount)
        }
    }
    
    private func saveBalance() {
        let balanceToSave: BalanceEntry
        
        if let existingBalance = balanceEntry {
            balanceToSave = existingBalance
        } else {
            let availableCreditValue = account.accountType == .creditCard ? availableCredit : nil
            balanceToSave = BalanceEntry(account: account, amount: amount, asOfDate: asOfDate, availableCredit: availableCreditValue)
            modelContext.insert(balanceToSave)
        }
        
        // Update balance properties
        balanceToSave.amount = amount
        balanceToSave.asOfDate = asOfDate
        balanceToSave.entryDate = Date()
        
        // Update available credit for credit cards
        if account.accountType == .creditCard {
            balanceToSave.availableCredit = availableCredit
        } else {
            balanceToSave.availableCredit = nil
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save balance: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    let account = Account(bankName: "Chase", accountName: "Freedom Unlimited", accountType: .creditCard)
    
    return BalanceEntryView(account: account, balanceEntry: nil)
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}