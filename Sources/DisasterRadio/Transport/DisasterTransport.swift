import Foundation
import Combine

enum TransportState {
    case disconnected
    case scanning
    case connecting
    case connected
}

protocol DisasterTransport: AnyObject {
    var statePublisher: AnyPublisher<TransportState, Never> { get }
    var receivedDataPublisher: AnyPublisher<Data, Never> { get }

    func connect()
    func disconnect()
    func send(_ data: Data)
}
