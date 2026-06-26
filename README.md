# disaster-radio iOS

A native Swift/SwiftUI iOS app for [disaster.radio](https://disaster.radio) — an open-source, LoRa-based emergency mesh communication network.

Connect to a disaster-radio node via **Bluetooth LE** or **Wi-Fi**, send and receive messages, and see nearby nodes in the mesh.

## Screenshots

_Chat, Nodes, and Settings tabs_

## Features

- **BLE transport** — connects to disaster-radio nodes advertising the Nordic UART Service (`DR-xxxxxxxxxxxx`)
- **Wi-Fi/WebSocket transport** — connects to a node's captive portal WebSocket at `ws://192.168.4.1/ws`
- **Chat** — send and receive mesh messages; first message sets your username
- **Nodes** — live route table showing nearby mesh nodes, hop count, and link metric
- **Settings** — username, Ed25519 keypair (stored in Keychain), Wi-Fi host config
- **No dependencies** — pure Apple frameworks only (CoreBluetooth, URLSession, CryptoKit, SwiftUI)

## Requirements

- iOS 16+
- Xcode 15+ (built and tested with Xcode 15.2)
- A [disaster-radio](https://github.com/sudomesh/disaster-radio) node running BLE or Wi-Fi firmware

## Building

```bash
git clone https://github.com/judytuna/disaster-radio-ios
open DisasterRadio.xcodeproj
```

In Xcode:
1. Select the `DisasterRadio` target → **Signing & Capabilities** → set your Development Team
2. Select your device in the device picker
3. Hit ▶ Run

## Connecting to a node

### Bluetooth LE
1. Power on a disaster-radio node with BLE firmware
2. In the app, tap the connection icon → **Bluetooth** tab → **Scan**
3. Your node will appear as `DR-xxxxxxxxxxxx` — tap to connect

### Wi-Fi
1. Join the disaster-radio node's Wi-Fi network on your phone
2. In the app, tap the connection icon → **Wi-Fi** tab
3. The default host `192.168.4.1` should work; tap **Connect**

## Architecture

```
Sources/DisasterRadio/
├── Transport/
│   ├── DisasterTransport.swift   # protocol both transports conform to
│   ├── BLETransport.swift        # CoreBluetooth, Nordic UART Service
│   └── WebSocketTransport.swift  # URLSession WebSocket, auto-reconnect
├── Protocol/
│   └── DisasterProtocol.swift    # binary framing, ACK tracking
├── Crypto/
│   └── CryptoManager.swift       # Ed25519 keypair via CryptoKit + Keychain
├── Model/
│   └── AppState.swift            # ObservableObject, route table parser
└── Views/
    ├── ContentView.swift
    ├── ChatView.swift
    ├── ConnectionView.swift
    ├── NodeListView.swift
    └── SettingsView.swift
```

## Wire protocol

Messages are binary-framed:
```
[2 bytes: UInt16 LE message ID][namespace char]['|'][UTF-8 payload]
```
- Namespace `c` = chat message
- Namespace `r` = route table (binary, 16 bytes per entry: 12 MAC + 2 hops + 2 metric)
- ACK from node: `[same 2-byte ID]['!']`

## Testing

22 unit tests across 3 suites, using **XCTest** (Apple's built-in test framework). No third-party test dependencies.

```bash
xcodebuild test \
  -project DisasterRadio.xcodeproj \
  -scheme DisasterRadio \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

| Suite | Tests | What's covered |
|---|---|---|
| `CryptoManagerTests` | 7 | Ed25519 key size, signing, verify round-trip, key stability across calls |
| `DisasterProtocolTests` | 8 | Binary framing, message ID incrementing, namespace/payload parsing, short message rejection, ACK packet format |
| `RouteParserTests` | 7 | Binary route table parsing, little-endian fields, one/two entries, leftover bytes, edge cases |

Tests use a `MockTransport` that implements `DisasterTransport` to inject raw bytes directly into the protocol layer without needing real hardware or a network connection. Async tests use `await fulfillment(of:)` (XCTest's async-safe expectation API, iOS 16+).

CI runs the full test suite on every push and pull request via GitHub Actions (`.github/workflows/build.yml`), using Apple Silicon macOS runners provided free for public repos.

## Frameworks used

All pure Apple frameworks — no third-party dependencies.

| Framework | Used for |
|---|---|
| **SwiftUI** | All UI — tabs, chat bubbles, forms, navigation |
| **Combine** | Publisher/subscriber wiring between transport, protocol, and UI layers |
| **CoreBluetooth** | BLE scanning, GATT connection, Nordic UART Service characteristic read/write/notify |
| **URLSession** | WebSocket connection (`URLSessionWebSocketTask`) |
| **CryptoKit** | Ed25519 keypair generation and detached signing (`Curve25519.Signing`) |
| **Security** | Keychain storage for the private key |
| **XCTest** | Unit tests |

## Related projects

- [disaster-radio firmware](https://github.com/sudomesh/disaster-radio) — the ESP32 firmware this app talks to
- [disaster-radio-android](https://github.com/beegee-tokyo/disaster-radio-android) — Android app (BLE only)
- [disaster-radio web app](https://github.com/sudomesh/disaster-radio) — browser UI served by the node over Wi-Fi

## License

MIT
