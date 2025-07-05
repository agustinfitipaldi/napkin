//
//  AccountListView.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query 
    private var accounts: [Account]
    
    @State private var showingAddAccount = false
    @State private var selectedAccount: Account?
    @State private var showingEditAccount = false
    @State private var showInactiveAccounts = false
    @State private var showingDeleteConfirmation = false
    @State private var accountToDelete: Account?
    @State private var showingQuickBalanceEntry = false
    
    public init() {}
    
    var body: some View {
        NavigationSplitView {
            accountList
        } detail: {
            if let selectedAccount {
                AccountDetailView(account: selectedAccount)
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        Text("Quick Balance Entry")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        
                        Text("Enter balances for all your accounts at once")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { showingQuickBalanceEntry = true }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Start Quick Entry")
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("b", modifiers: .command)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            AccountFormView(account: nil)
        }
        .sheet(isPresented: $showingEditAccount) {
            if let selectedAccount {
                AccountFormView(account: selectedAccount)
            }
        }
        .sheet(isPresented: $showingQuickBalanceEntry) {
            QuickBalanceEntryView()
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                accountToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    hardDeleteAccount(account)
                    accountToDelete = nil
                }
            }
        } message: {
            if let account = accountToDelete {
                Text("Are you sure you want to permanently delete \(account.bankName) \(account.accountName)? This action cannot be undone and will delete all associated balance entries.")
            }
        }
    }
    
    private var accountList: some View {
        List(selection: $selectedAccount) {
            ForEach(AccountType.allCases, id: \.self) { type in
                let accountsForType = accounts.filter { account in
                    account.accountType == type && (showInactiveAccounts || account.isActive)
                }.sorted { $0.bankName < $1.bankName }
                if !accountsForType.isEmpty {
                    Section(type.rawValue) {
                        ForEach(accountsForType) { account in
                            AccountRowView(account: account)
                                .tag(account)
                                .contextMenu {
                                    if account.isActive {
                                        Button("Inactivate Account") {
                                            inactivateAccount(account)
                                        }
                                    } else {
                                        Button("Reactivate Account") {
                                            reactivateAccount(account)
                                        }
                                    }
                                    
                                    Button("Delete Account", role: .destructive) {
                                        accountToDelete = account
                                        showingDeleteConfirmation = true
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingQuickBalanceEntry = true }) {
                    Label("Quick Balance Entry", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { showingAddAccount = true }) {
                    Label("Add Account", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { 
                    if selectedAccount != nil {
                        showingEditAccount = true 
                    }
                }) {
                    Label("Edit Account", systemImage: "pencil")
                }
                .disabled(selectedAccount == nil)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { 
                    showInactiveAccounts.toggle()
                }) {
                    Label(showInactiveAccounts ? "Hide Inactive" : "Show Inactive", 
                          systemImage: showInactiveAccounts ? "eye.slash" : "eye")
                }
            }
        }
    }
    
    private func inactivateAccount(_ account: Account) {
        withAnimation {
            account.isActive = false
            account.updatedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func reactivateAccount(_ account: Account) {
        withAnimation {
            account.isActive = true
            account.updatedAt = Date()
            try? modelContext.save()
        }
    }
    
    private func hardDeleteAccount(_ account: Account) {
        withAnimation {
            modelContext.delete(account)
            try? modelContext.save()
            // Clear selection if this was the selected account
            if selectedAccount?.id == account.id {
                selectedAccount = nil
            }
        }
    }
}

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\BalanceEntry.entryDate, order: .reverse)])
    private var allBalanceEntries: [BalanceEntry]
    
    @State private var showingAddBalance = false
    @State private var selectedBalanceEntry: BalanceEntry?
    @State private var showingEditBalance = false
    
    init(account: Account) {
        self.account = account
    }
    
    private var balanceEntries: [BalanceEntry] {
        allBalanceEntries.filter { $0.account?.id == account.id }
    }
    
    private var currentBalance: Decimal {
        balanceEntries.first?.effectiveBalance() ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Account Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconForAccountType(account.accountType))
                            .foregroundColor(colorForAccountType(account.accountType))
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(account.bankName)
                                    .font(.headline)
                                if !account.isActive {
                                    Text("INACTIVE")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(account.accountName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let lastFour = account.lastFourDigits {
                            Text("••••\(lastFour)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Current Balance
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatCurrency(currentBalance))
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .foregroundColor(currentBalance < 0 ? .red : .primary)
                        
                        // Show available credit for credit cards
                        if account.accountType == .creditCard,
                           let availableCredit = balanceEntries.first?.effectiveAvailableCredit() {
                            Text("Available: \(formatCurrency(availableCredit))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Account Details
                if account.accountType.hasAPR || account.accountType.hasMinimumPayment {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Details")
                            .font(.headline)
                        
                        if account.accountType.hasAPR {
                            DetailRow(label: "APR", value: formatAPR(account))
                        }
                        
                        if account.accountType.hasMinimumPayment {
                            DetailRow(label: "Minimum Payment", value: formatMinimumPayment(account))
                        }
                        
                        if account.accountType.hasCreditLimit, let limit = account.creditLimit {
                            DetailRow(label: "Credit Limit", value: formatCurrency(limit))
                            
                            if let utilization = account.creditUtilization(balance: currentBalance) {
                                DetailRow(label: "Utilization", value: String(format: "%.1f%%", NSDecimalNumber(decimal: utilization).doubleValue))
                            }
                        }
                        
                        if let dueDay = account.paymentDueDay {
                            DetailRow(label: "Due Date", value: "Day \(dueDay) of each month")
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                // Recent Balance History
                if !balanceEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Balances")
                            .font(.headline)
                        
                        ForEach(balanceEntries.prefix(5)) { entry in
                            HStack {
                                Text(entry.asOfDate, style: .date)
                                    .foregroundColor(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatCurrency(entry.effectiveBalance()))
                                        .fontWeight(.medium)
                                    
                                    // Show available credit for credit cards
                                    if account.accountType == .creditCard,
                                       let availableCredit = entry.effectiveAvailableCredit() {
                                        Text("Avail: \(formatCurrency(availableCredit))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .onTapGesture {
                                selectedBalanceEntry = entry
                                showingEditBalance = true
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(account.accountName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Balance") {
                    showingAddBalance = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            if !account.isActive {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Reactivate") {
                        reactivateAccount()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddBalance) {
            BalanceEntryView(account: account, balanceEntry: nil)
        }
        .sheet(isPresented: $showingEditBalance) {
            if let selectedBalanceEntry {
                BalanceEntryView(account: account, balanceEntry: selectedBalanceEntry)
            }
        }
    }
    
    private func reactivateAccount() {
        account.isActive = true
        account.updatedAt = Date()
        try? modelContext.save()
    }
    
    private func formatAPR(_ account: Account) -> String {
        // Get current prime rate (we'll need to add this to GlobalSettings)
        let primeRate: Decimal = 8.5 // Placeholder
        
        if let apr = account.currentAPR(primeRate: primeRate) {
            return String(format: "%.2f%%", NSDecimalNumber(decimal: apr).doubleValue)
        }
        return "N/A"
    }
    
    private func formatMinimumPayment(_ account: Account) -> String {
        if let amount = account.minimumPaymentAmount {
            return formatCurrency(amount)
        } else if let percent = account.minimumPaymentPercent {
            return String(format: "%.1f%% of balance", NSDecimalNumber(decimal: percent * 100).doubleValue)
        }
        return "N/A"
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}


#Preview {
    AccountListView()
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}
