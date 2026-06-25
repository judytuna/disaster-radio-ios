import Foundation
import Combine

final class WebSocketTransport: NSObject, DisasterTransport {

    // MARK: - Publishers
    private let stateSubject = CurrentValueSubject<TransportState, Never>(.disconnected)
    private let receivedSubject = PassthroughSubject<Data, Never>()

    var statePublisher: AnyPublisher<TransportState, Never> { stateSubject.eraseToAnyPublisher() }
    var receivedDataPublisher: AnyPublisher<Data, Never> { receivedSubject.eraseToAnyPublisher() }

    // MARK: - Config
    var host: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?

    init(host: String = "192.168.4.1") {
        self.host = host
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    // MARK: - DisasterTransport

    func connect() {
        guard stateSubject.value == .disconnected else { return }
        stateSubject.send(.connecting)
        openSocket()
    }

    func disconnect() {
        reconnectWorkItem?.cancel()
        reconnectAttempt = 0
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        stateSubject.send(.disconnected)
    }

    func send(_ data: Data) {
        guard stateSubject.value == .connected else { return }
        webSocketTask?.send(.data(data)) { _ in }
    }

    // MARK: - Private

    private func openSocket() {
        guard let url = URL(string: "ws://\(host)/ws") else { return }
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receive()
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.receivedSubject.send(data)
                case .string(let str):
                    if let data = str.data(using: .utf8) {
                        self.receivedSubject.send(data)
                    }
                @unknown default:
                    break
                }
                self.receive()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func handleDisconnect() {
        webSocketTask = nil
        stateSubject.send(.disconnected)
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), 60.0)
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.stateSubject.value == .disconnected else { return }
            self.stateSubject.send(.connecting)
            self.openSocket()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketTransport: URLSessionWebSocketDelegate {

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        reconnectAttempt = 0
        stateSubject.send(.connected)
        receive()
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        handleDisconnect()
    }
}
