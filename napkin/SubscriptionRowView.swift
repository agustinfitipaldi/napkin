//
//  SubscriptionRowView.swift
//  napkin
//
//  Created by Claude Code on 7/6/25.
//

import SwiftUI

struct SubscriptionRowView: View {
    let subscription: Subscription
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: subscription.category.systemImage)
                .foregroundColor(colorForCategory(subscription.category))
                .font(.title2)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                // Subscription name
                HStack {
                    Text(subscription.name)
                        .font(.headline)
                        .foregroundColor(subscription.isActive ? .primary : .secondary)
                    
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
                
                // Frequency and annual cost
                HStack {
                    Text(subscription.frequencyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Annual: \(formatCurrency(subscription.annualCost))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Notes preview (if available)
                if let notes = subscription.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
            
            // Monthly cost
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(subscription.monthlyCost))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(subscription.isActive ? .primary : .secondary)
                
                Text("per month")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(subscription.isActive ? 1.0 : 0.6)
    }
}

func colorForCategory(_ category: SubscriptionCategory) -> Color {
    switch category.color {
    case "purple": return .purple
    case "blue": return .blue
    case "yellow": return .yellow
    case "orange": return .orange
    case "green": return .green
    case "red": return .red
    case "indigo": return .indigo
    case "brown": return .brown
    case "pink": return .pink
    case "cyan": return .cyan
    case "secondary": return .secondary
    default: return .primary
    }
}

#Preview {
    List {
        SubscriptionRowView(subscription: Subscription(
            name: "Netflix",
            amount: 15.99,
            timesPerYear: 12,
            category: .entertainment,
            notes: "Family plan shared with roommates"
        ))
        
        SubscriptionRowView(subscription: Subscription(
            name: "Adobe Creative Suite",
            amount: 599.88,
            timesPerYear: 1,
            category: .productivity,
            notes: "Annual subscription for design work"
        ))
        
        SubscriptionRowView(subscription: {
            let sub = Subscription(
                name: "Gym Membership",
                amount: 25.00,
                timesPerYear: 12,
                category: .fitness
            )
            sub.isActive = false
            return sub
        }())
    }
}