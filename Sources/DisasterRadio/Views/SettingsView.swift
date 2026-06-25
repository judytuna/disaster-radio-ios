import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showResetKeyAlert = false
    @State private var usernameInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    HStack {
                        TextField("Username", text: $usernameInput)
                            .autocorrectionDisabled()
                        Button("Save") {
                            appState.username = usernameInput.trimmingCharacters(in: .whitespaces)
                            appState.hasJoined = !appState.username.isEmpty
                        }
                        .buttonStyle(.bordered)
                        .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    let pubKey = CryptoManager.shared.publicKeyData
                        .map { String(format: "%02x", $0) }.joined()
                    Text(pubKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button("Regenerate Keys", role: .destructive) {
                        showResetKeyAlert = true
                    }
                } header: {
                    Text("Public Key")
                } footer: {
                    Text("Your Ed25519 public key identifies you on the network.")
                }

                Section("Connection") {
                    HStack {
                        Text("Wi-Fi Host")
                        Spacer()
                        TextField("192.168.4.1", text: $appState.wifiHost)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.shortVersionString)
                    Link("disaster.radio", destination: URL(string: "https://disaster.radio")!)
                    Link("Source code", destination: URL(string: "https://github.com/sudomesh/disaster-radio")!)
                }
            }
            .navigationTitle("Settings")
            .onAppear { usernameInput = appState.username }
            .alert("Regenerate Keys?", isPresented: $showResetKeyAlert) {
                Button("Regenerate", role: .destructive) {
                    CryptoManager.shared.regenerateKeys()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will generate a new identity. Other nodes won't recognize messages from your old key.")
            }
        }
    }
}

private extension Bundle {
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
