//
//  SubscriptionFormView.swift
//  napkin
//
//  Created by Claude Code on 7/6/25.
//

import SwiftUI
import SwiftData

struct SubscriptionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let subscription: Subscription?
    
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var timesPerYear: Int = 12
    @State private var category: SubscriptionCategory = .entertainment
    @State private var notes: String = ""
    @State private var isActive: Bool = true
    
    @State private var showingDeleteConfirmation = false
    @State private var amountText: String = ""
    @State private var frequencyText: String = "12"
    
    private var isEditing: Bool {
        subscription != nil
    }
    
    private var title: String {
        isEditing ? "Edit Subscription" : "Add Subscription"
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0 && timesPerYear > 0
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
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Save") {
                    saveSubscription()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)

            Divider()
            
            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subscription Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Subscription Name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                        }
                        
                        CurrencyField(
                            label: "Amount Per Payment",
                            value: $amount,
                            stringValue: $amountText
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Times Per Year")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                TextField("12", text: $frequencyText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.leading)
                                    .onChange(of: frequencyText) { _, newValue in
                                        if let parsed = Int(newValue), parsed > 0, parsed <= 365 {
                                            timesPerYear = parsed
                                        }
                                    }
                                Text("payments per year")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Category", selection: $category) {
                                ForEach(SubscriptionCategory.allCases, id: \.self) { cat in
                                    Label(cat.rawValue, systemImage: cat.systemImage)
                                        .tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Cost Breakdown Section
                    if amount > 0 && timesPerYear > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cost Breakdown")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            let tempSubscription = Subscription(name: "", amount: amount, timesPerYear: timesPerYear, category: category)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Frequency:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(tempSubscription.frequencyDescription)
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Text("Monthly Cost:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(tempSubscription.monthlyCost))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Annual Cost:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatCurrency(tempSubscription.annualCost))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Details (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Keep track of usage, renewal dates, or other important details", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    
                    // Active Status Section (only when editing)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Status")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            Toggle("Active", isOn: $isActive)
                            
                            Text("Inactive subscriptions won't be included in totals")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Delete Button Section (only when editing)
                    if isEditing {
                        VStack(alignment: .leading, spacing: 12) {
                            Button("Delete Subscription", role: .destructive) {
                                showingDeleteConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadSubscriptionData()
        }
        .alert("Delete Subscription", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSubscription()
            }
        } message: {
            Text("Are you sure you want to delete this subscription? This action cannot be undone.")
        }
    }
    
    private var frequencyDescription: String {
        let tempSubscription = Subscription(name: "", amount: 0, timesPerYear: timesPerYear, category: category)
        return tempSubscription.frequencyDescription
    }
    
    private func loadSubscriptionData() {
        guard let subscription = subscription else { return }
        
        name = subscription.name
        amount = subscription.amount
        amountText = formatDecimalForEditing(subscription.amount)
        timesPerYear = subscription.timesPerYear
        frequencyText = String(subscription.timesPerYear)
        category = subscription.category
        notes = subscription.notes ?? ""
        isActive = subscription.isActive
    }
    
    private func saveSubscription() {
        if let existingSubscription = subscription {
            // Update existing
            existingSubscription.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingSubscription.amount = amount
            existingSubscription.timesPerYear = timesPerYear
            existingSubscription.category = category
            existingSubscription.notes = notes.isEmpty ? nil : notes
            existingSubscription.isActive = isActive
            existingSubscription.updatedAt = Date()
        } else {
            // Create new
            let newSubscription = Subscription(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                amount: amount,
                timesPerYear: timesPerYear,
                category: category,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(newSubscription)
        }
        
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteSubscription() {
        guard let subscription = subscription else { return }
        
        modelContext.delete(subscription)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SubscriptionFormView(subscription: nil)
        .modelContainer(for: [Subscription.self], inMemory: true)
}