import Foundation
import Combine
import CoreBluetooth

struct ChatMessage: Identifiable {
    enum Kind { case remote, `self`, status }
    let id = UUID()
    let text: String
    let kind: Kind
    let timestamp: Date
}

struct RouteEntry: Identifiable {
    let id = UUID()
    let mac: String
    let hops: Int
    let metric: Int
}

enum ConnectionMode {
    case ble, wifi
}

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published
    @Published var messages: [ChatMessage] = []
    @Published var routes: [RouteEntry] = []
    @Published var connectionState: TransportState = .disconnected
    @Published var connectionMode: ConnectionMode = .ble
    @Published var username: String = ""
    @Published var hasJoined: Bool = false

    // BLE scan results
    @Published var discoveredPeripherals: [CBPeripheral] = []

    // WiFi host (user-configurable)
    @Published var wifiHost: String = "192.168.4.1"

    // MARK: - Internals
    let bleTransport = BLETransport()
    let wsTransport: WebSocketTransport
    private let proto = DisasterProtocol()
    private var cancellables = Set<AnyCancellable>()

    init() {
        wsTransport = WebSocketTransport(host: "192.168.4.1")
        setupBLE()
    }

    // MARK: - Connection

    func startBLE() {
        connectionMode = .ble
        wsTransport.disconnect()
        proto.bind(to: bleTransport)
        bleTransport.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
        bleTransport.connect()

        bleTransport.discoveredPeripheralsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral in
                guard let self else { return }
                if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                    self.discoveredPeripherals.append(peripheral)
                }
            }
            .store(in: &cancellables)
    }

    func connectBLE(to peripheral: CBPeripheral) {
        bleTransport.connect(to: peripheral)
    }

    func startWifi() {
        connectionMode = .wifi
        bleTransport.disconnect()
        wsTransport.host = wifiHost
        proto.bind(to: wsTransport)
        wsTransport.statePublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
        wsTransport.connect()
    }

    func disconnect() {
        switch connectionMode {
        case .ble: bleTransport.disconnect()
        case .wifi: wsTransport.disconnect()
        }
    }

    // MARK: - Messaging

    func send(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let payload: String
        let kind: ChatMessage.Kind

        if !hasJoined {
            username = text
            hasJoined = true
            payload = "~ \(text) joined the channel"
            kind = .status
        } else {
            payload = "<\(username)> \(text)"
            kind = .`self`
        }

        proto.send(namespace: "c", payload: payload) { [weak self] result in
            guard let self else { return }
            if case .success = result {
                self.messages.append(ChatMessage(text: payload, kind: kind, timestamp: Date()))
            }
        }
    }

    // MARK: - Private

    private func setupBLE() {
        proto.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handle(msg) }
            .store(in: &cancellables)
    }

    private func handle(_ msg: IncomingMessage) {
        switch msg.namespace {
        case "c":
            guard let text = String(data: msg.payload, encoding: .utf8) else { return }
            messages.append(ChatMessage(text: text, kind: .remote, timestamp: Date()))
        case "r":
            routes = parseRoutes(msg.payload)
        default:
            break
        }
    }

    func parseRoutes(_ data: Data) -> [RouteEntry] {
        // Each route entry is 16 hex chars = 8 bytes in the web app's display,
        // but the raw binary is 16 bytes: 12 MAC + 2 hops + 2 metric.
        let entrySize = 16
        guard data.count >= entrySize else { return [] }
        var entries: [RouteEntry] = []
        var offset = 0
        while offset + entrySize <= data.count {
            let macBytes = data[offset..<(offset + 12)]
            let hops = Int(data[offset + 12]) | (Int(data[offset + 13]) << 8)
            let metric = Int(data[offset + 14]) | (Int(data[offset + 15]) << 8)
            let mac = macBytes.map { String(format: "%02x", $0) }.joined(separator: ":")
            entries.append(RouteEntry(mac: mac, hops: hops, metric: metric))
            offset += entrySize
        }
        return entries
    }
}
