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
            Subscription.self,
            PaycheckConfig.self,
        ])

        // Configure CloudKit sync with iCloud
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // Enable iCloud sync
        )

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
        #if os(macOS)
        .defaultSize(width: 1040, height: 650)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif

        #if os(macOS)
        Window("Settings", id: "settings") {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        #endif
    }
    
    private func openSettings() {
        #if os(macOS)
        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // The window will be created automatically when first accessed
        }
        #endif
    }
}
