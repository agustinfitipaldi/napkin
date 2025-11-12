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
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        // Try CloudKit sync first, fall back to local-only if it fails
        // CloudKit requires: iCloud account signed in + proper entitlements configured
        do {
            let cloudConfig = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(
                for: Account.self, BalanceEntry.self, GlobalSettings.self,
                PaymentPlan.self, PlannedPayment.self, Subscription.self, PaycheckConfig.self,
                configurations: cloudConfig
            )
        } catch {
            // CloudKit not available - fall back to local storage
            print("⚠️ CloudKit unavailable, using local storage only: \(error)")
            do {
                let localConfig = ModelConfiguration(
                    isStoredInMemoryOnly: false
                )
                return try ModelContainer(
                    for: Account.self, BalanceEntry.self, GlobalSettings.self,
                    PaymentPlan.self, PlannedPayment.self, Subscription.self, PaycheckConfig.self,
                    configurations: localConfig
                )
            } catch {
                fatalError("Could not create ModelContainer even with local storage: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Trigger CloudKit sync when app becomes active
                // SwiftData will automatically import remote changes
                try? sharedModelContainer.mainContext.save()
            }
        }
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
