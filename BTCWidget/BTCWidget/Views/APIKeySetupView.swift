import SwiftUI

struct APIKeySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tradingSettings = TradingSettings.shared

    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var backendURL = "https://btc-trading-backend.fly.dev"
    @State private var showProductionWarning = false

    enum TestResult {
        case success(balance: String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Backend Status Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Backend Mode")
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("API keys stored securely on server")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("Your Binance API keys are stored on the secure backend server, not on this device.")
                }

                // Trading Mode Section
                Section {
                    // Production Mode Toggle
                    Toggle(isOn: Binding(
                        get: { tradingSettings.isProduction },
                        set: { newValue in
                            if newValue {
                                showProductionWarning = true
                            } else {
                                tradingSettings.isProduction = false
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: tradingSettings.isProduction ? "exclamationmark.triangle.fill" : "testtube.2")
                                .foregroundColor(tradingSettings.isProduction ? .red : .green)
                            VStack(alignment: .leading) {
                                Text("Production Mode")
                                    .font(.body)
                                Text(tradingSettings.isProduction ? "REAL MONEY" : "Testnet (fake money)")
                                    .font(.caption)
                                    .foregroundColor(tradingSettings.isProduction ? .red : .secondary)
                            }
                        }
                    }
                    .tint(.red)

                    // Safe Mode Toggle (only relevant in production)
                    if tradingSettings.isProduction {
                        Toggle(isOn: $tradingSettings.safeMode) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Safe Mode")
                                        .font(.body)
                                    Text("Uses 1/1000 of amounts")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.orange)
                    }
                } header: {
                    Text("Trading Mode")
                } footer: {
                    if tradingSettings.isProduction {
                        if tradingSettings.safeMode {
                            Text("⚠️ Production with Safe Mode: Orders will use 1/1000 of displayed amounts ($2000 → $2)")
                        } else {
                            Text("🚨 FULL PRODUCTION: Orders will use REAL money at FULL amounts!")
                        }
                    } else {
                        Text("Testnet uses fake money for testing. No real funds at risk.")
                    }
                }

                // Backend URL Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backend URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(backendURL)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Connected to \(tradingSettings.isProduction ? "Binance Production" : "Binance Testnet") via backend.")
                }

                // Test Connection Section
                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        switch result {
                        case .success(let balance):
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Connection successful!")
                                        .foregroundColor(.green)
                                }
                                Text("USDT Balance: \(balance)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .failure(let error):
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // How It Works Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Backend Mode Works:")
                            .font(.headline)

                        InfoRow(icon: "server.rack", text: "API keys stored on secure Fly.io server")
                        InfoRow(icon: "lock.shield", text: "Keys never touch your device")
                        InfoRow(icon: "network.badge.shield.half.filled", text: "All trades routed through backend")
                        InfoRow(icon: "bell.badge", text: "Push notifications for order fills")
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Information")
                }

                // Security Notes Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("JWT authentication (15min tokens)", systemImage: "key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("HTTPS encrypted communication", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Backend in Singapore (Binance accessible)", systemImage: "globe.asia.australia")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Label("Rust binary - impossible to decompile", systemImage: "shield.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Security Features")
                }

                // Debug Section
                Section {
                    NavigationLink {
                        DebugView()
                    } label: {
                        HStack {
                            Image(systemName: "ant.fill")
                                .foregroundColor(.orange)
                            Text("Debug & Diagnostics")
                        }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Test all backend endpoints and view detailed error messages.")
                }
            }
            .navigationTitle("Backend Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-test on appear
                testConnection()
            }
            .alert("Enable Production Mode?", isPresented: $showProductionWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Enable with Safe Mode") {
                    tradingSettings.safeMode = true
                    tradingSettings.isProduction = true
                }
                Button("Enable FULL Production", role: .destructive) {
                    tradingSettings.safeMode = false
                    tradingSettings.isProduction = true
                }
            } message: {
                Text("⚠️ WARNING: Production mode uses REAL MONEY!\n\nSafe Mode uses 1/1000 of amounts.\nFull Production uses actual amounts.\n\nAre you sure?")
            }
        }
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let balance = try await BackendService.shared.getBalance()
                await MainActor.run {
                    isTesting = false
                    testResult = .success(balance: balance.usdtBalance.formatAsCurrency(maximumFractionDigits: 2))
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResult = .failure(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    APIKeySetupView()
}
