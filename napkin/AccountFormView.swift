//
//  AccountFormView.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import SwiftData

struct AccountFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let account: Account?
    
    @State private var bankName = ""
    @State private var accountName = ""
    @State private var accountType: AccountType = .checking
    @State private var lastFourDigits = ""
    
    // Credit fields
    @State private var creditLimit: Decimal = 0
    @State private var creditLimitString = ""
    
    // APR fields
    @State private var aprType: APRType = .fixed
    @State private var fixedAPR: Decimal = 0
    @State private var fixedAPRString = ""
    @State private var marginAPR: Decimal = 0
    @State private var marginAPRString = ""
    @State private var maxAPR: Decimal = 0
    @State private var maxAPRString = ""
    
    // Payment fields
    @State private var paymentDueDay = 15
    @State private var minimumPaymentAmount: Decimal = 0
    @State private var minimumPaymentAmountString = ""
    @State private var minimumPaymentPercent: Decimal = 0.01
    @State private var minimumPaymentPercentString = "1.0"
    @State private var useFixedMinimum = true
    @State private var lateFee: Decimal = 0
    @State private var lateFeeString = ""
    
    @State private var notes = ""
    
    // Validation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var isEditing: Bool {
        account != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Text(isEditing ? "Edit Account" : "Add Account")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    saveAccount()
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
                    // Account Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Information")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bank Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Bank Name", text: $bankName)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Account Name", text: $accountName)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account Type")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Account Type", selection: $accountType) {
                                ForEach(AccountType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last 4 Digits (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Last 4 Digits", text: $lastFourDigits)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                                .onReceive(lastFourDigits.publisher.collect()) { value in
                                    // Limit to 4 digits
                                    let filtered = String(value.prefix(4)).filter { $0.isNumber }
                                    if filtered != lastFourDigits {
                                        lastFourDigits = filtered
                                    }
                                }
                        }
                    }
                
                    // Credit limit section (only for credit cards)
                    if accountType.hasCreditLimit {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Credit Limit")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            CurrencyField(
                                label: "Credit Limit",
                                value: $creditLimit,
                                stringValue: $creditLimitString
                            )
                        }
                    }
                
                    // APR section (only for debt accounts)
                    if accountType.hasAPR {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Interest Rate (APR)")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("APR Type")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("APR Type", selection: $aprType) {
                                    Text("Fixed Rate").tag(APRType.fixed)
                                    Text("Variable Rate").tag(APRType.variable)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            if aprType == .fixed {
                                PercentField(
                                    label: "Fixed APR",
                                    value: $fixedAPR,
                                    stringValue: $fixedAPRString
                                )
                            } else {
                                PercentField(
                                    label: "Margin (added to Prime Rate)",
                                    value: $marginAPR,
                                    stringValue: $marginAPRString
                                )
                                
                                PercentField(
                                    label: "Maximum APR (Optional)",
                                    value: $maxAPR,
                                    stringValue: $maxAPRString
                                )
                            }
                        }
                    }
                
                    // Payment section (only for debt accounts)
                    if accountType.hasMinimumPayment {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Payment Information")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Payment Due Day")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("Due Day", selection: $paymentDueDay) {
                                    ForEach(1...31, id: \.self) { day in
                                        Text("\(day)").tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Minimum Payment Method")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("Minimum Payment Method", selection: $useFixedMinimum) {
                                    Text("Fixed Amount").tag(true)
                                    Text("Percentage of Balance").tag(false)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            if useFixedMinimum {
                                CurrencyField(
                                    label: "Minimum Payment Amount",
                                    value: $minimumPaymentAmount,
                                    stringValue: $minimumPaymentAmountString
                                )
                            } else {
                                PercentField(
                                    label: "Minimum Payment Percentage",
                                    value: $minimumPaymentPercent,
                                    stringValue: $minimumPaymentPercentString
                                )
                            }
                            
                            CurrencyField(
                                label: "Late Fee (Optional)",
                                value: $lateFee,
                                stringValue: $lateFeeString
                            )
                        }
                    }
                
                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Notes", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, maxWidth: 500, minHeight: 500)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadAccountData()
        }
    }
    
    private var isFormValid: Bool {
        !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func loadAccountData() {
        guard let account = account else { return }
        
        bankName = account.bankName
        accountName = account.accountName
        accountType = account.accountType
        lastFourDigits = account.lastFourDigits ?? ""
        
        // Credit limit
        creditLimit = account.creditLimit ?? 0
        creditLimitString = formatDecimalForEditing(creditLimit)
        
        // APR
        aprType = account.aprType ?? .fixed
        fixedAPR = account.fixedAPR ?? 0
        fixedAPRString = formatDecimalForEditing(fixedAPR)
        marginAPR = account.marginAPR ?? 0
        marginAPRString = formatDecimalForEditing(marginAPR)
        maxAPR = account.maxAPR ?? 0
        maxAPRString = formatDecimalForEditing(maxAPR)
        
        // Payment
        paymentDueDay = account.paymentDueDay ?? 15
        minimumPaymentAmount = account.minimumPaymentAmount ?? 0
        minimumPaymentAmountString = formatDecimalForEditing(minimumPaymentAmount)
        minimumPaymentPercent = account.minimumPaymentPercent ?? 0.01
        minimumPaymentPercentString = formatDecimalForEditing(minimumPaymentPercent * 100)
        useFixedMinimum = account.minimumPaymentAmount != nil
        lateFee = account.lateFee ?? 0
        lateFeeString = formatDecimalForEditing(lateFee)
        
        notes = account.notes ?? ""
    }
    
    private func saveAccount() {
        let accountToSave: Account
        
        if let existingAccount = account {
            accountToSave = existingAccount
        } else {
            accountToSave = Account(
                bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
                accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                accountType: accountType
            )
            modelContext.insert(accountToSave)
        }
        
        // Update account properties
        accountToSave.bankName = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        accountToSave.accountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        accountToSave.accountType = accountType
        accountToSave.lastFourDigits = lastFourDigits.isEmpty ? nil : lastFourDigits
        accountToSave.updatedAt = Date()
        
        // Credit limit
        if accountType.hasCreditLimit {
            accountToSave.creditLimit = creditLimit > 0 ? creditLimit : nil
        } else {
            accountToSave.creditLimit = nil
        }
        
        // APR
        if accountType.hasAPR {
            accountToSave.aprType = aprType
            if aprType == .fixed {
                accountToSave.fixedAPR = fixedAPR > 0 ? fixedAPR : nil
                accountToSave.marginAPR = nil
                accountToSave.maxAPR = nil
            } else {
                accountToSave.fixedAPR = nil
                accountToSave.marginAPR = marginAPR > 0 ? marginAPR : nil
                accountToSave.maxAPR = maxAPR > 0 ? maxAPR : nil
            }
        } else {
            accountToSave.aprType = nil
            accountToSave.fixedAPR = nil
            accountToSave.marginAPR = nil
            accountToSave.maxAPR = nil
        }
        
        // Payment
        if accountType.hasMinimumPayment {
            accountToSave.paymentDueDay = paymentDueDay
            if useFixedMinimum {
                accountToSave.minimumPaymentAmount = minimumPaymentAmount > 0 ? minimumPaymentAmount : nil
                accountToSave.minimumPaymentPercent = nil
            } else {
                accountToSave.minimumPaymentAmount = nil
                accountToSave.minimumPaymentPercent = minimumPaymentPercent > 0 ? minimumPaymentPercent : nil
            }
            accountToSave.lateFee = lateFee > 0 ? lateFee : nil
        } else {
            accountToSave.paymentDueDay = nil
            accountToSave.minimumPaymentAmount = nil
            accountToSave.minimumPaymentPercent = nil
            accountToSave.lateFee = nil
        }
        
        accountToSave.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save account: \(error.localizedDescription)"
            showingError = true
        }
    }
    
}

// Custom field components
struct CurrencyField: View {
    let label: String
    @Binding var value: Decimal
    @Binding var stringValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("$0.00", text: $stringValue)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .onChange(of: stringValue) { _, newValue in
                    if let decimal = parseDecimal(from: newValue) {
                        value = decimal
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

struct PercentField: View {
    let label: String
    @Binding var value: Decimal
    @Binding var stringValue: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("0.00", text: $stringValue)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.leading)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .onChange(of: stringValue) { _, newValue in
                        if let decimal = parsePercent(from: newValue) {
                            value = decimal
                        }
                    }
                
                Text("%")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AccountFormView(account: nil)
        .modelContainer(for: [Account.self], inMemory: true)
}
