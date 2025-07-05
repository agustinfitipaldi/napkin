//
//  AccountRowView.swift
//  napkin
//
//  Created by Claude Code on 7/5/25.
//

import SwiftUI
import SwiftData

struct AccountRowView: View {
    let account: Account
    @Query(sort: [SortDescriptor(\BalanceEntry.entryDate, order: .reverse)])
    private var allBalanceEntries: [BalanceEntry]
    
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
        HStack(spacing: 12) {
            // Account type icon
            Image(systemName: iconForAccountType(account.accountType))
                .foregroundColor(account.isActive ? colorForAccountType(account.accountType) : .secondary)
                .font(.title3)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(account.bankName)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(account.isActive ? .primary : .secondary)
                    
                    if !account.isActive {
                        Text("INACTIVE")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Current balance
                    Text(formatCurrency(currentBalance))
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(account.isActive ? 
                                       balanceColor(for: currentBalance, accountType: account.accountType) : 
                                       .secondary)
                }
                
                HStack {
                    Text(account.accountName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .opacity(account.isActive ? 1.0 : 0.6)
                    
                    if let lastFour = account.lastFourDigits {
                        Text("••••\(lastFour)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Additional info based on account type
                    if account.accountType.hasAPR, let apr = account.currentAPR(primeRate: 8.5) {
                        Text(String(format: "%.1f%% APR", NSDecimalNumber(decimal: apr).doubleValue))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Credit utilization for credit cards
                if account.accountType.hasCreditLimit,
                   let utilization = account.creditUtilization(balance: currentBalance),
                   currentBalance > 0 {
                    HStack {
                        Text("Utilization:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%%", NSDecimalNumber(decimal: utilization).doubleValue))
                            .font(.caption2)
                            .foregroundColor(utilizationColor(utilization))
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    
}

#Preview {
    let account = Account(bankName: "Chase", accountName: "Freedom Unlimited", accountType: .creditCard)
    account.creditLimit = 5000
    account.fixedAPR = 18.24
    account.lastFourDigits = "1234"
    
    return AccountRowView(account: account)
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}