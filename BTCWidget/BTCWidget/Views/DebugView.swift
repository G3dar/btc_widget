import SwiftUI

struct DebugView: View {
    @StateObject private var tradingSettings = TradingSettings.shared
    @State private var testResults: [BackendService.TestResult] = []
    @State private var isRunning = false
    @State private var hasRun = false

    var body: some View {
        NavigationView {
            List {
                Section("Debug Settings") {
                    Toggle(isOn: $tradingSettings.debugMode) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("Debug Mode")
                                Text("Shows simulate fill buttons on pending pairs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        runTests()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.blue)
                            Text("Run All Tests")
                            Spacer()
                            if isRunning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRunning)
                }

                if hasRun {
                    Section("Results") {
                        ForEach(testResults, id: \.endpoint) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(result.success ? .green : .red)
                                    Text(result.endpoint)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(String(format: "%.0fms", result.duration * 1000))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(result.success ? .secondary : .red)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Summary") {
                        let passed = testResults.filter { $0.success }.count
                        let failed = testResults.filter { !$0.success }.count

                        HStack {
                            Label("\(passed) Passed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Label("\(failed) Failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(failed > 0 ? .red : .secondary)
                        }
                        .font(.subheadline)
                    }
                }

                Section("Backend Info") {
                    LabeledContent("URL", value: "btc-trading-backend.fly.dev")
                    LabeledContent("Environment", value: "Testnet")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func runTests() {
        isRunning = true
        testResults = []

        Task {
            let results = await BackendService.shared.runDiagnostics()

            await MainActor.run {
                testResults = results
                isRunning = false
                hasRun = true
            }
        }
    }
}

#Preview {
    DebugView()
}
