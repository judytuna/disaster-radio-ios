import SwiftUI
import CoreBluetooth

struct ConnectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showWiFiSheet = false
    @State private var wifiHostInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $appState.connectionMode) {
                    Text("Bluetooth").tag(ConnectionMode.ble)
                    Text("Wi-Fi").tag(ConnectionMode.wifi)
                }
                .pickerStyle(.segmented)
                .padding()

                if appState.connectionMode == .ble {
                    bleSection
                } else {
                    wifiSection
                }
            }
            .navigationTitle("Connect")
        }
    }

    // MARK: - BLE

    private var bleSection: some View {
        VStack {
            HStack {
                statusDot
                Text(bleStatusText)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(appState.connectionState == .scanning ? "Stop" : "Scan") {
                    if appState.connectionState == .scanning || appState.connectionState == .disconnected {
                        appState.discoveredPeripherals = []
                        appState.startBLE()
                    } else {
                        appState.disconnect()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()

            List(appState.discoveredPeripherals, id: \.identifier) { peripheral in
                Button {
                    appState.connectBLE(to: peripheral)
                } label: {
                    HStack {
                        Image(systemName: "wave.3.right")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(peripheral.name ?? "Unknown")
                                .font(.headline)
                            Text(peripheral.identifier.uuidString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.connectionState == .connecting {
                            ProgressView()
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var bleStatusText: String {
        switch appState.connectionState {
        case .disconnected: return "Not connected"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        }
    }

    // MARK: - WiFi

    private var wifiSection: some View {
        Form {
            Section("Device IP") {
                TextField("192.168.4.1", text: $appState.wifiHost)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    appState.startWifi()
                } label: {
                    HStack {
                        Spacer()
                        if appState.connectionState == .connecting {
                            ProgressView()
                        } else {
                            Text(appState.connectionState == .connected ? "Reconnect" : "Connect")
                        }
                        Spacer()
                    }
                }
                .disabled(appState.connectionState == .connecting)
            }

            if appState.connectionState == .connected {
                Section {
                    HStack {
                        statusDot
                        Text("Connected to \(appState.wifiHost)")
                    }
                }
            }
        }
    }

    // MARK: - Shared

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 10, height: 10)
    }

    private var dotColor: Color {
        switch appState.connectionState {
        case .connected: return .green
        case .connecting, .scanning: return .yellow
        case .disconnected: return .gray
        }
    }
}
