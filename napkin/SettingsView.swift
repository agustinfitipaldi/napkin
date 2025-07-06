//
//  SettingsView.swift
//  napkin
//
//  Created by Agustin Fitipaldi on 7/6/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var globalSettings: [GlobalSettings]
    
    @State private var primeRate: String = ""
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isExporting = false
    @State private var isImporting = false
    
    private var currentSettings: GlobalSettings? {
        globalSettings.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Settings content
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prime Rate")
                            .font(.headline)
                        
                        HStack {
                            TextField("8.50", text: $primeRate)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            
                            Text("%")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Update") {
                                updatePrimeRate()
                            }
                            .disabled(primeRate.isEmpty)
                        }
                        
                        Text("The prime rate is used to calculate variable APR rates for credit accounts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Financial Settings")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Data")
                                    .font(.headline)
                                Text("Save your financial data to a JSON file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showingExportPicker = true }) {
                                HStack {
                                    if isExporting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    Text("Export")
                                }
                            }
                            .disabled(isExporting || isImporting)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import Data")
                                    .font(.headline)
                                Text("Load financial data from a JSON file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { showingImportPicker = true }) {
                                HStack {
                                    if isImporting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text("Import")
                                }
                            }
                            .disabled(isExporting || isImporting)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Data Management")
                }
            }
            .formStyle(.grouped)
            
            // Bottom buttons
            HStack {
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .navigationTitle("Settings")
        .frame(width: 500, height: 350)
        .onAppear {
            loadCurrentSettings()
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: NapkinDataDocument(),
            contentType: .json,
            defaultFilename: "napkin-data-\(DateFormatter.exportFilename.string(from: Date()))"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadCurrentSettings() {
        primeRate = currentSettings?.currentPrimeRate.description ?? "8.50"
    }
    
    private func updatePrimeRate() {
        guard let rate = Decimal(string: primeRate) else {
            showAlert(title: "Invalid Rate", message: "Please enter a valid prime rate.")
            return
        }
        
        guard rate >= 0 && rate <= 30 else {
            showAlert(title: "Invalid Rate", message: "Prime rate must be between 0% and 30%.")
            return
        }
        
        if let settings = currentSettings {
            settings.currentPrimeRate = rate
            settings.lastUpdated = Date()
        } else {
            let newSettings = GlobalSettings(primeRate: rate)
            modelContext.insert(newSettings)
        }
        
        do {
            try modelContext.save()
            showAlert(title: "Success", message: "Prime rate updated to \(rate)%.")
        } catch {
            showAlert(title: "Error", message: "Failed to update prime rate: \(error.localizedDescription)")
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            exportData(to: url)
        case .failure(let error):
            showAlert(title: "Export Error", message: "Failed to select export location: \(error.localizedDescription)")
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importData(from: url)
        case .failure(let error):
            showAlert(title: "Import Error", message: "Failed to select import file: \(error.localizedDescription)")
        }
    }
    
    private func exportData(to url: URL) {
        isExporting = true
        
        Task {
            do {
                let exportManager = DataExportManager(modelContext: modelContext)
                try await exportManager.exportData(to: url)
                
                await MainActor.run {
                    isExporting = false
                    showAlert(title: "Export Complete", message: "Data exported successfully to \(url.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    showAlert(title: "Export Error", message: "Failed to export data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func importData(from url: URL) {
        isImporting = true
        
        Task {
            do {
                let importManager = DataImportManager(modelContext: modelContext)
                let result = try await importManager.importData(from: url)
                
                await MainActor.run {
                    isImporting = false
                    showAlert(title: "Import Complete", message: "Successfully imported \(result.accountsImported) accounts, \(result.balanceEntriesImported) balance entries, and \(result.subscriptionsImported) subscriptions.")
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    showAlert(title: "Import Error", message: "Failed to import data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Document Support

struct NapkinDataDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.json]
    static var writableContentTypes: [UTType] = [.json]
    
    init() {}
    
    init(configuration: ReadConfiguration) throws {
        // Not used for export-only document
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // This will be handled by the export manager
        return FileWrapper(regularFileWithContents: Data())
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let exportFilename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}

#Preview {
    SettingsView()
        .modelContainer(for: [GlobalSettings.self], inMemory: true)
}