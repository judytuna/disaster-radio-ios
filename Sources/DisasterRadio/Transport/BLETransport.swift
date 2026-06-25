import Foundation
import CoreBluetooth
import Combine

// Nordic UART Service UUIDs
private let uartServiceUUID      = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
private let rxCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // phone → device
private let txCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // device → phone

final class BLETransport: NSObject, DisasterTransport {

    // MARK: - Publishers
    private let stateSubject = CurrentValueSubject<TransportState, Never>(.disconnected)
    private let receivedSubject = PassthroughSubject<Data, Never>()

    var statePublisher: AnyPublisher<TransportState, Never> { stateSubject.eraseToAnyPublisher() }
    var receivedDataPublisher: AnyPublisher<Data, Never> { receivedSubject.eraseToAnyPublisher() }

    // Publishes discovered peripherals for the scan UI
    let discoveredPeripheralsPublisher = PassthroughSubject<CBPeripheral, Never>()

    // MARK: - Private state
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var writeQueue: [Data] = []

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - DisasterTransport

    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        stateSubject.send(.connecting)
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func connect() {
        guard centralManager.state == .poweredOn else { return }
        stateSubject.send(.scanning)
        centralManager.scanForPeripherals(withServices: [uartServiceUUID], options: nil)
    }

    func disconnect() {
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        reset()
    }

    func send(_ data: Data) {
        guard let p = peripheral, let rx = rxCharacteristic else {
            writeQueue.append(data)
            return
        }
        // BLE MTU for NUS is typically 20 bytes without negotiation; firmware sets 260 but
        // iOS negotiates its own MTU. Chunk to maximumWriteValueLength.
        let mtu = p.maximumWriteValueLength(for: .withoutResponse)
        var offset = 0
        while offset < data.count {
            let end = min(offset + mtu, data.count)
            let chunk = data.subdata(in: offset..<end)
            p.writeValue(chunk, for: rx, type: .withoutResponse)
            offset = end
        }
    }

    // MARK: - Private

    private func reset() {
        peripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        stateSubject.send(.disconnected)
    }

    private func flushWriteQueue() {
        let queued = writeQueue
        writeQueue = []
        queued.forEach { send($0) }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLETransport: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && stateSubject.value == .scanning {
            central.scanForPeripherals(withServices: [uartServiceUUID], options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard let name = peripheral.name, name.hasPrefix("DR-") else { return }
        discoveredPeripheralsPublisher.send(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([uartServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reset()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        reset()
    }
}

// MARK: - CBPeripheralDelegate
extension BLETransport: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == uartServiceUUID }) else { return }
        peripheral.discoverCharacteristics([rxCharacteristicUUID, txCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for char in service.characteristics ?? [] {
            if char.uuid == rxCharacteristicUUID { rxCharacteristic = char }
            if char.uuid == txCharacteristicUUID {
                txCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        if rxCharacteristic != nil && txCharacteristic != nil {
            stateSubject.send(.connected)
            flushWriteQueue()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == txCharacteristicUUID, let data = characteristic.value else { return }
        receivedSubject.send(data)
    }
}
