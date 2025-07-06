//
//  ContentView.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/5/25.
//

import SwiftUI
import SwiftData
import Charts

enum SidebarSection: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case subscriptions = "Subscriptions"
    case dashboard = "Dashboard"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .accounts: return "creditcard"
        case .subscriptions: return "repeat"
        case .dashboard: return "chart.bar"
        }
    }
}

struct SidebarView: View {
    @Binding var selectedSection: SidebarSection
    
    var body: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            NavigationLink(value: section) {
                Label(section.rawValue, systemImage: section.systemImage)
            }
        }
        .navigationTitle("Napkin")
        .navigationSplitViewColumnWidth(min: 120, ideal: 140, max: 160)
    }
}

struct ContentView: View {
    @State private var selectedSection: SidebarSection = .accounts
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .accounts:
                AccountListView()
            case .subscriptions:
                SubscriptionsView()
            case .dashboard:
                DashboardView()
            }
        }
    }
}

struct SubscriptionsView: View {
    var body: some View {
        VStack {
            Text("Subscriptions")
                .font(.largeTitle)
                .padding()
            
            Text("Track your subscription costs")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Subscriptions")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query(sort: [SortDescriptor(\BalanceEntry.entryDate, order: .reverse)]) 
    private var balanceEntries: [BalanceEntry]
    @Query private var globalSettings: [GlobalSettings]
    
    @State private var extraPaymentAmount: Decimal = 0
    @State private var selectedStrategy: PaymentStrategy = .avalanche
    
    private var currentPrimeRate: Decimal {
        globalSettings.first?.currentPrimeRate ?? 8.5
    }
    
    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }
    
    private var currentBalanceEntries: [BalanceEntry] {
        // Get most recent balance entry for each account
        var latestEntries: [BalanceEntry] = []
        for account in activeAccounts {
            if let latestEntry = balanceEntries.first(where: { $0.account?.id == account.id }) {
                latestEntries.append(latestEntry)
            }
        }
        return latestEntries
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Key Metrics Section
                keyMetricsSection
                
                // Payment Strategy Section
                paymentStrategySection
                
                // Historical Chart Section
                historicalChartSection
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .onAppear {
            ensureGlobalSettingsExist()
        }
    }
    
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financial Overview")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                MetricCard(
                    title: "Total Debt",
                    value: formatCurrency(totalDebt),
                    color: .red,
                    icon: "creditcard"
                )
                
                MetricCard(
                    title: "Total Assets",
                    value: formatCurrency(totalAssets),
                    color: .green,
                    icon: "banknote"
                )
                
                MetricCard(
                    title: "Net Worth",
                    value: formatCurrency(netWorth),
                    color: netWorth >= 0 ? .green : .red,
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                MetricCard(
                    title: "Available Credit",
                    value: formatCurrency(totalAvailableCredit),
                    color: .blue,
                    icon: "creditcard.circle"
                )
                
                MetricCard(
                    title: "Monthly Minimums",
                    value: formatCurrency(totalMinimumPayments),
                    color: .orange,
                    icon: "calendar"
                )
                
                MetricCard(
                    title: "Credit Utilization",
                    value: String(format: "%.1f%%", NSDecimalNumber(decimal: creditUtilization).doubleValue),
                    color: creditUtilization > 30 ? .red : .green,
                    icon: "percent"
                )
            }
        }
    }
    
    private var paymentStrategySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Strategy")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                // Strategy selection and extra payment input
                HStack {
                    Picker("Strategy", selection: $selectedStrategy) {
                        Text("Avalanche (Highest APR)").tag(PaymentStrategy.avalanche)
                        Text("Snowball (Lowest Balance)").tag(PaymentStrategy.snowball)
                    }
                    .pickerStyle(.segmented)
                    
                    Spacer()
                    
                    HStack {
                        Text("Extra Payment:")
                        TextField("$0", value: $extraPaymentAmount, format: .currency(code: "USD"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                // Payment plan display
                if !debtAccounts.isEmpty && extraPaymentAmount > 0 {
                    paymentPlanView
                } else if debtAccounts.isEmpty {
                    Text("No debt accounts found - you're debt free! 🎉")
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text("Enter an extra payment amount to see your payment strategy")
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var paymentPlanView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Month's Payment Plan")
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(generatePaymentPlan(), id: \.accountId) { payment in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payment.accountName)
                            .fontWeight(.medium)
                        Text(payment.bankName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(payment.suggestedAmount))
                            .fontWeight(.semibold)
                        Text("(min: \(formatCurrency(payment.minimumAmount)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                if payment.accountId != generatePaymentPlan().last?.accountId {
                    Divider()
                }
            }
            
            Divider()
                .background(Color.primary)
            
            HStack {
                Text("Total Payment")
                    .fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(totalMinimumPayments + extraPaymentAmount))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private var historicalChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Worth Trend")
                .font(.title2)
                .fontWeight(.semibold)
            
            if historicalNetWorthData.count >= 2 {
                Chart(historicalNetWorthData) { dataPoint in
                    LineMark(
                        x: .value("Month", dataPoint.date),
                        y: .value("Net Worth", dataPoint.netWorth)
                    )
                    .foregroundStyle(dataPoint.netWorth >= 0 ? .green : .red)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Month", dataPoint.date),
                        y: .value("Net Worth", dataPoint.netWorth)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (dataPoint.netWorth >= 0 ? Color.green : Color.red).opacity(0.3),
                                (dataPoint.netWorth >= 0 ? Color.green : Color.red).opacity(0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Decimal.self) {
                                Text(formatCurrency(amount))
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits))
                                    .font(.caption)
                            }
                        }
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Not enough data for chart")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Enter balances for at least 2 different months to see your net worth trend")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
    
    private func ensureGlobalSettingsExist() {
        if globalSettings.isEmpty {
            let settings = GlobalSettings()
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }
    
    // MARK: - Computed Properties
    
    private var totalDebt: Decimal {
        let debtAccountTypes: [AccountType] = [.creditCard, .loan, .mortgage]
        return currentBalanceEntries
            .filter { entry in
                guard let account = entry.account else { return false }
                return debtAccountTypes.contains(account.accountType)
            }
            .reduce(0) { $0 + $1.effectiveBalance() }
    }
    
    private var totalAssets: Decimal {
        let assetAccountTypes: [AccountType] = [.checking, .savings, .ira, .retirement401k, .brokerage]
        return currentBalanceEntries
            .filter { entry in
                guard let account = entry.account else { return false }
                return assetAccountTypes.contains(account.accountType)
            }
            .reduce(0) { $0 + $1.effectiveBalance() }
    }
    
    private var netWorth: Decimal {
        return totalAssets - totalDebt
    }
    
    private var totalAvailableCredit: Decimal {
        return activeAccounts.totalAvailableCredit(from: currentBalanceEntries)
    }
    
    private var totalMinimumPayments: Decimal {
        return activeAccounts.totalMinimumPayments(from: currentBalanceEntries, primeRate: currentPrimeRate)
    }
    
    private var creditUtilization: Decimal {
        return activeAccounts.overallCreditUtilization(from: currentBalanceEntries) ?? 0
    }
    
    private var debtAccounts: [Account] {
        return activeAccounts.filter { $0.accountType.hasMinimumPayment }
    }
    
    private var historicalNetWorthData: [NetWorthDataPoint] {
        let calendar = Calendar.current
        var monthlyData: [String: NetWorthDataPoint] = [:]
        
        // Group balance entries by month
        for entry in balanceEntries {
            let monthKey = calendar.dateInterval(of: .month, for: entry.asOfDate)?.start ?? entry.asOfDate
            let monthKeyString = DateFormatter.monthYearKey.string(from: monthKey)
            
            if monthlyData[monthKeyString] == nil {
                monthlyData[monthKeyString] = NetWorthDataPoint(date: monthKey, netWorth: 0)
            }
        }
        
        // Calculate net worth for each month
        for (monthKey, dataPoint) in monthlyData {
            let monthStart = dataPoint.date
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            
            // Get the most recent balance entry for each account within this month
            var monthlyBalances: [Account: Decimal] = [:]
            
            for account in activeAccounts {
                let accountEntries = balanceEntries.filter { entry in
                    entry.account?.id == account.id &&
                    entry.asOfDate >= monthStart &&
                    entry.asOfDate < monthEnd
                }
                .sorted { $0.asOfDate > $1.asOfDate }
                
                if let latestEntry = accountEntries.first {
                    monthlyBalances[account] = latestEntry.effectiveBalance()
                }
            }
            
            // Calculate net worth for this month
            var monthlyNetWorth: Decimal = 0
            for (account, balance) in monthlyBalances {
                switch account.accountType {
                case .checking, .savings, .ira, .retirement401k, .brokerage:
                    monthlyNetWorth += balance
                case .creditCard, .loan, .mortgage:
                    monthlyNetWorth -= balance
                case .other:
                    break
                }
            }
            
            monthlyData[monthKey] = NetWorthDataPoint(date: monthStart, netWorth: monthlyNetWorth)
        }
        
        return monthlyData.values
            .sorted { $0.date < $1.date }
            .suffix(12) // Show last 12 months
            .map { $0 }
    }
    
    private func generatePaymentPlan() -> [PaymentPlanItem] {
        var plans: [PaymentPlanItem] = []
        var remainingExtra = extraPaymentAmount
        
        // First, add minimum payments for all debt accounts
        for account in debtAccounts {
            if let balanceEntry = currentBalanceEntries.first(where: { $0.account?.id == account.id }) {
                let minimumPayment = account.minimumPayment(
                    balance: balanceEntry.effectiveBalance(),
                    primeRate: currentPrimeRate
                )
                
                plans.append(PaymentPlanItem(
                    accountId: account.id,
                    accountName: account.accountName,
                    bankName: account.bankName,
                    balance: balanceEntry.effectiveBalance(),
                    apr: account.currentAPR(primeRate: currentPrimeRate) ?? 0,
                    minimumAmount: minimumPayment,
                    suggestedAmount: minimumPayment
                ))
            }
        }
        
        // Sort by strategy
        switch selectedStrategy {
        case .avalanche:
            plans.sort { $0.apr > $1.apr }
        case .snowball:
            plans.sort { $0.balance < $1.balance }
        }
        
        // Distribute extra payment
        var index = 0
        while remainingExtra > 0 && index < plans.count {
            let extraForThisAccount = min(remainingExtra, plans[index].balance - plans[index].suggestedAmount)
            if extraForThisAccount > 0 {
                plans[index].suggestedAmount += extraForThisAccount
                remainingExtra -= extraForThisAccount
            }
            index += 1
        }
        
        return plans
    }
}

// MARK: - Supporting Types and Views

enum PaymentStrategy: String, CaseIterable {
    case avalanche = "avalanche"
    case snowball = "snowball"
}

struct PaymentPlanItem {
    let accountId: UUID
    let accountName: String
    let bankName: String
    let balance: Decimal
    let apr: Decimal
    let minimumAmount: Decimal
    var suggestedAmount: Decimal
}

struct NetWorthDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let netWorth: Decimal
}

extension DateFormatter {
    static let monthYearKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}
