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
    @State private var showingSettings = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        #if os(iOS)
        // Use TabView on iPhone, NavigationSplitView on iPad
        if horizontalSizeClass == .compact {
            iPhoneLayout
        } else {
            iPadLayout
        }
        #else
        // macOS always uses NavigationSplitView
        macOSLayout
        #endif
    }

    // MARK: - iPhone Layout (TabView)
    private var iPhoneLayout: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                AccountListView()
                    .navigationTitle("Accounts")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Accounts", systemImage: "creditcard")
            }
            .tag(SidebarSection.accounts)

            NavigationStack {
                SubscriptionsView()
                    .navigationTitle("Subscriptions")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Subscriptions", systemImage: "repeat")
            }
            .tag(SidebarSection.subscriptions)

            NavigationStack {
                DashboardView()
                    .navigationTitle("Dashboard")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSettings = true
                            } label: {
                                Label("Settings", systemImage: "gear")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar")
            }
            .tag(SidebarSection.dashboard)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)
    private var iPadLayout: some View {
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - macOS Layout (NavigationSplitView)
    private var macOSLayout: some View {
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
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    
    @State private var showingAddSubscription = false
    @State private var selectedSubscription: Subscription?
    @State private var showingEditSubscription = false
    @State private var showInactiveSubscriptions = false
    @State private var selectedCategory: SubscriptionCategory?
    
    private var filteredSubscriptions: [Subscription] {
        subscriptions.filter { subscription in
            let activeFilter = showInactiveSubscriptions || subscription.isActive
            let categoryFilter = selectedCategory == nil || subscription.category == selectedCategory
            return activeFilter && categoryFilter
        }
    }
    
    private var totalMonthlyCost: Decimal {
        subscriptions.totalMonthlyCost()
    }
    
    var body: some View {
        NavigationSplitView {
            subscriptionList
        } detail: {
            if let selectedSubscription {
                SubscriptionDetailView(subscription: selectedSubscription)
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "repeat.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        
                        Text("Subscription Tracker")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                        
                        Text("Keep track of all your recurring expenses")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if totalMonthlyCost > 0 {
                            Text("Total: \(formatCurrency(totalMonthlyCost))/month")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: { showingAddSubscription = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add Subscription")
                        }
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddSubscription) {
            SubscriptionFormView(subscription: nil)
        }
        .sheet(isPresented: $showingEditSubscription) {
            if let selectedSubscription {
                SubscriptionFormView(subscription: selectedSubscription)
            }
        }
    }
    
    private var subscriptionList: some View {
        List(selection: $selectedSubscription) {
            ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                let subscriptionsForCategory = filteredSubscriptions.filter { $0.category == category }
                    .sorted { $0.name < $1.name }
                
                if !subscriptionsForCategory.isEmpty {
                    Section {
                        ForEach(subscriptionsForCategory) { subscription in
                            SubscriptionRowView(subscription: subscription)
                                .tag(subscription)
                                .onTapGesture {
                                    if selectedSubscription == subscription {
                                        selectedSubscription = nil
                                    } else {
                                        selectedSubscription = subscription
                                    }
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        selectedSubscription = subscription
                                        showingEditSubscription = true
                                    }
                                    
                                    if subscription.isActive {
                                        Button("Mark Inactive") {
                                            toggleSubscriptionActive(subscription)
                                        }
                                    } else {
                                        Button("Mark Active") {
                                            toggleSubscriptionActive(subscription)
                                        }
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Image(systemName: category.systemImage)
                                .foregroundColor(colorForCategory(category))
                            Text(category.rawValue)
                            Spacer()
                            Text(formatCurrency(subscriptions.totalMonthlyCost(for: category)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if filteredSubscriptions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No subscriptions found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your first subscription to get started")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Subscription") {
                        showingAddSubscription = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Subscriptions")
        .navigationSplitViewColumnWidth(min: 350, ideal: 450)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSubscription = true }) {
                    Label("Add Subscription", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { 
                    if selectedSubscription != nil {
                        showingEditSubscription = true 
                    }
                }) {
                    Label("Edit Subscription", systemImage: "pencil")
                }
                .disabled(selectedSubscription == nil)
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(action: { 
                    showInactiveSubscriptions.toggle()
                }) {
                    Label(showInactiveSubscriptions ? "Hide Inactive" : "Show Inactive", 
                          systemImage: showInactiveSubscriptions ? "eye.slash" : "eye")
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button("All Categories") {
                        selectedCategory = nil
                    }
                    
                    ForEach(SubscriptionCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedCategory = selectedCategory == category ? nil : category
                        }) {
                            Label(category.rawValue, systemImage: category.systemImage)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    private func toggleSubscriptionActive(_ subscription: Subscription) {
        subscription.isActive.toggle()
        subscription.updatedAt = Date()
        try? modelContext.save()
    }
}

struct SubscriptionDetailView: View {
    let subscription: Subscription
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Subscription Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: subscription.category.systemImage)
                            .foregroundColor(colorForCategory(subscription.category))
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(subscription.name)
                                    .font(.headline)
                                if !subscription.isActive {
                                    Text("INACTIVE")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(4)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(subscription.category.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Monthly Cost
                    Text(formatCurrency(subscription.monthlyCost))
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("per month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                // Cost Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cost Breakdown")
                        .font(.headline)
                    
                    DetailRow(label: "Amount per payment", value: formatCurrency(subscription.amount))
                    DetailRow(label: "Frequency", value: subscription.frequencyDescription)
                    DetailRow(label: "Weekly cost", value: formatCurrency(subscription.weeklyCost))
                    DetailRow(label: "Monthly cost", value: formatCurrency(subscription.monthlyCost))
                    DetailRow(label: "Annual cost", value: formatCurrency(subscription.annualCost))
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                // Notes
                if let notes = subscription.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                        
                        Text(notes)
                            .font(.body)
                    }
                    .padding()
                    .background(.thinMaterial)
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(subscription.name)
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [Account]
    @Query(sort: [SortDescriptor(\BalanceEntry.entryDate, order: .reverse)]) 
    private var balanceEntries: [BalanceEntry]
    @Query private var globalSettings: [GlobalSettings]
    @Query private var subscriptions: [Subscription]
    @Query private var paycheckConfigs: [PaycheckConfig]
    
    @State private var safetyAmount: Decimal = 500
    @State private var selectedStrategy: PaymentStrategy = .avalanche
    @State private var nextPaycheckDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var secondPaycheckDate: Date = Calendar.current.date(byAdding: .day, value: 29, to: Date()) ?? Date()
    @State private var nextPaycheckAmount: Decimal = 2000
    
    private var currentPrimeRate: Decimal {
        globalSettings.first?.currentPrimeRate ?? 8.5
    }
    
    private var totalCheckingBalance: Decimal {
        let checkingAccounts = activeAccounts.filter { $0.accountType == .checking }
        var total: Decimal = 0
        
        for account in checkingAccounts {
            if let balanceEntry = currentBalanceEntries.first(where: { $0.account?.id == account.id }) {
                total += balanceEntry.effectiveBalance()
            }
        }
        
        return total
    }
    
    private var availableForPayments: Decimal {
        let totalAvailable = totalCheckingBalance - safetyAmount
        return max(0, totalAvailable)
    }
    
    // Period 1: Now → Next Paycheck Date
    private var period1Accounts: [Account] {
        let today = Date()
        return debtAccounts.filter { account in
            account.isDueBetween(startDate: today, endDate: nextPaycheckDate)
        }
    }
    
    // Period 2: Next Paycheck Date → Second Paycheck Date  
    private var period2Accounts: [Account] {
        return debtAccounts.filter { account in
            account.isDueBetween(startDate: nextPaycheckDate, endDate: secondPaycheckDate)
        }
    }
    
    private var period2TotalMinimums: Decimal {
        var total: Decimal = 0
        for account in period2Accounts {
            if let balanceEntry = currentBalanceEntries.first(where: { $0.account?.id == account.id }) {
                let minimumPayment = account.minimumPayment(
                    balance: balanceEntry.effectiveBalance(),
                    primeRate: currentPrimeRate
                )
                total += minimumPayment
            }
        }
        return total
    }
    
    // Shortfall protection: if next paycheck can't cover period 2, bring forward the difference
    private var period2Shortfall: Decimal {
        let shortfall = period2TotalMinimums - nextPaycheckAmount
        return max(0, shortfall)
    }
    
    // Check if paycheck period is too long (>45 days)
    private var isLongPaycheckPeriod: Bool {
        let daysBetween = Calendar.current.dateComponents([.day], from: Date(), to: secondPaycheckDate).day ?? 0
        return daysBetween > 45
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
            
            // Second row - subscriptions and future features
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                MetricCard(
                    title: "Monthly Subscriptions",
                    value: formatCurrency(totalMonthlySubscriptions),
                    color: .purple,
                    icon: "repeat"
                )
                
                MetricCard(
                    title: "Income Sources",
                    value: "Coming Soon",
                    color: .secondary,
                    icon: "dollarsign.circle"
                )
                
                MetricCard(
                    title: "Cash Flow",
                    value: "Coming Soon",
                    color: .secondary,
                    icon: "chart.line.uptrend.xyaxis.circle"
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
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Next Paycheck:")
                            DatePicker("", selection: $nextPaycheckDate, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 120)
                        }
                        HStack {
                            Text("Second Paycheck:")
                            DatePicker("", selection: $secondPaycheckDate, displayedComponents: .date)
                                .labelsHidden()
                                .frame(width: 120)
                        }
                        HStack {
                            Text("Paycheck Amount:")
                            TextField("$0", value: $nextPaycheckAmount, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        HStack {
                            Text("Safety Buffer:")
                            TextField("$0", value: $safetyAmount, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Checking: \(formatCurrency(totalCheckingBalance)) - Safety: \(formatCurrency(safetyAmount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Available for payments: \(formatCurrency(availableForPayments))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(availableForPayments > 0 ? .primary : .red)
                            
                            if period2Shortfall > 0 {
                                Text("⚠️ Next paycheck shortfall: \(formatCurrency(period2Shortfall))")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            if isLongPaycheckPeriod {
                                Text("⚠️ Long paycheck period - calculations may be unstable")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Payment plan display
                if !debtAccounts.isEmpty && availableForPayments > 0 {
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
            .background(.thinMaterial)
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
                    Image(systemName: payment.category.systemImage)
                        .foregroundColor(payment.category.color)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payment.accountName)
                            .fontWeight(.medium)
                        HStack {
                            Text(payment.bankName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(payment.category.rawValue)
                                .font(.caption)
                                .foregroundColor(payment.category.color)
                        }
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
                Text(formatCurrency(totalMinimumPayments + availableForPayments))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
                .background(.thinMaterial)
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
                .background(.thinMaterial)
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
    
    private var totalMonthlySubscriptions: Decimal {
        return subscriptions.totalMonthlyCost()
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
        var remainingCash = availableForPayments
        
        // TIER 1: Period 1 minimums + shortfall from Period 2
        
        // Add Period 1 minimum payments (urgent accounts due before next paycheck)
        for account in period1Accounts {
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
                    suggestedAmount: minimumPayment,
                    category: .urgent
                ))
                
                remainingCash = max(0, remainingCash - minimumPayment)
            }
        }
        
        // Add shortfall protection: allocate additional funds to cover Period 2 shortfall
        if period2Shortfall > 0 && remainingCash > 0 {
            let shortfallToCover = min(period2Shortfall, remainingCash)
            
            // Find the highest priority Period 2 account to receive shortfall payment
            let period2AccountsSorted: [Account]
            switch selectedStrategy {
            case .avalanche:
                period2AccountsSorted = period2Accounts.sorted { account1, account2 in
                    let apr1 = account1.currentAPR(primeRate: currentPrimeRate) ?? 0
                    let apr2 = account2.currentAPR(primeRate: currentPrimeRate) ?? 0
                    return apr1 > apr2
                }
            case .snowball:
                period2AccountsSorted = period2Accounts.sorted { account1, account2 in
                    let balance1 = currentBalanceEntries.first(where: { $0.account?.id == account1.id })?.effectiveBalance() ?? 0
                    let balance2 = currentBalanceEntries.first(where: { $0.account?.id == account2.id })?.effectiveBalance() ?? 0
                    return balance1 < balance2
                }
            }
            
            if let topPriorityAccount = period2AccountsSorted.first,
               let balanceEntry = currentBalanceEntries.first(where: { $0.account?.id == topPriorityAccount.id }) {
                
                plans.append(PaymentPlanItem(
                    accountId: topPriorityAccount.id,
                    accountName: topPriorityAccount.accountName + " (Shortfall)",
                    bankName: topPriorityAccount.bankName,
                    balance: balanceEntry.effectiveBalance(),
                    apr: topPriorityAccount.currentAPR(primeRate: currentPrimeRate) ?? 0,
                    minimumAmount: 0,
                    suggestedAmount: shortfallToCover,
                    category: .urgent
                ))
                
                remainingCash -= shortfallToCover
            }
        }
        
        // TIER 2: Strategic debt reduction with remaining funds
        // Get all accounts not in Period 1 or Period 2 (or have extra capacity)
        let allPeriodAccountIds = Set(period1Accounts.map { $0.id } + period2Accounts.map { $0.id })
        let strategicAccounts = debtAccounts.filter { !allPeriodAccountIds.contains($0.id) }
        
        var strategicPlans: [PaymentPlanItem] = []
        for account in strategicAccounts {
            if let balanceEntry = currentBalanceEntries.first(where: { $0.account?.id == account.id }) {
                strategicPlans.append(PaymentPlanItem(
                    accountId: account.id,
                    accountName: account.accountName,
                    bankName: account.bankName,
                    balance: balanceEntry.effectiveBalance(),
                    apr: account.currentAPR(primeRate: currentPrimeRate) ?? 0,
                    minimumAmount: 0,
                    suggestedAmount: 0,
                    category: .strategic
                ))
            }
        }
        
        // Sort strategic accounts by priority
        switch selectedStrategy {
        case .avalanche:
            strategicPlans.sort { $0.apr > $1.apr }
        case .snowball:
            strategicPlans.sort { $0.balance < $1.balance }
        }
        
        // Allocate remaining cash to strategic accounts
        var strategicIndex = 0
        while remainingCash > 0 && strategicIndex < strategicPlans.count {
            let maxPayment = min(remainingCash, strategicPlans[strategicIndex].balance)
            if maxPayment > 0 {
                strategicPlans[strategicIndex].suggestedAmount = maxPayment
                remainingCash -= maxPayment
            }
            strategicIndex += 1
        }
        
        // Combine all plans and filter out $0 payments
        plans.append(contentsOf: strategicPlans)
        
        return plans.filter { $0.suggestedAmount > 0 }
    }
}

// MARK: - Supporting Types and Views

enum PaymentStrategy: String, CaseIterable {
    case avalanche = "avalanche"
    case snowball = "snowball"
}

enum PaymentCategory: String, CaseIterable {
    case urgent = "Urgent"
    case strategic = "Strategic"
    
    var color: Color {
        switch self {
        case .urgent: return .red
        case .strategic: return .blue
        }
    }
    
    var systemImage: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .strategic: return "target"
        }
    }
}

struct PaymentPlanItem {
    let accountId: UUID
    let accountName: String
    let bankName: String
    let balance: Decimal
    let apr: Decimal
    let minimumAmount: Decimal
    var suggestedAmount: Decimal
    var category: PaymentCategory = .urgent
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
        .background(.thinMaterial)
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}
