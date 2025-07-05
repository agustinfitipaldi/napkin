//
//  ContentView.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/5/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        AccountListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Account.self, BalanceEntry.self], inMemory: true)
}
