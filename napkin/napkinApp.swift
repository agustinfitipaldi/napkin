//
//  napkinApp.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/5/25.
//

import SwiftUI
import SwiftData

@main
struct napkinApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            BalanceEntry.self,
            GlobalSettings.self,
            PaymentPlan.self,
            PlannedPayment.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
