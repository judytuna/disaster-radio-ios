import Foundation
import Combine

// Wire format:
//   [2 bytes: UInt16 LE message ID][namespace ASCII char]['|'][UTF-8 payload]
// ACK from device:
//   [2 bytes: same message ID]['!']

struct IncomingMessage {
    let namespace: Character
    let payload: Data
}

final class DisasterProtocol {

    var messagePublisher: AnyPublisher<IncomingMessage, Never> { messageSubject.eraseToAnyPublisher() }
    private let messageSubject = PassthroughSubject<IncomingMessage, Never>()

    private var transport: (any DisasterTransport)?
    private var cancellables = Set<AnyCancellable>()

    private var curID: UInt16 = 0
    private var pendingACKs: [UInt16: (Result<Void, Error>) -> Void] = [:]
    private var ackTimeouts: [UInt16: DispatchWorkItem] = [:]

    // MARK: - Transport binding

    func bind(to transport: any DisasterTransport) {
        self.transport = transport
        transport.receivedDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in self?.handle(data) }
            .store(in: &cancellables)
    }

    // MARK: - Send

    func send(namespace: Character, payload: String, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let id = nextID()
        var msg = Data()
        var idLE = id.littleEndian
        msg.append(contentsOf: withUnsafeBytes(of: &idLE, Array.init))
        let body = "\(namespace)|\(payload)"
        msg.append(contentsOf: body.utf8)
        transport?.send(msg)

        if let completion {
            pendingACKs[id] = completion
            let work = DispatchWorkItem { [weak self] in
                guard let self, let cb = self.pendingACKs.removeValue(forKey: id) else { return }
                self.ackTimeouts.removeValue(forKey: id)
                cb(.failure(ProtocolError.ackTimeout))
            }
            ackTimeouts[id] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
        }
    }

    // MARK: - Private

    private func nextID() -> UInt16 {
        defer {
            curID = curID == UInt16.max ? 0 : curID + 1
        }
        return curID
    }

    private func handle(_ data: Data) {
        guard data.count > 2 else { return }
        let id = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let body = data.dropFirst(2)

        // ACK
        if body.count == 1 && body[0] == UInt8(ascii: "!") {
            ackTimeouts[id]?.cancel()
            ackTimeouts.removeValue(forKey: id)
            if let cb = pendingACKs.removeValue(forKey: id) {
                cb(.success(()))
            }
            return
        }

        // namespace|payload
        guard let pipeIdx = body.firstIndex(of: UInt8(ascii: "|")),
              pipeIdx > body.startIndex,
              let nsChar = String(bytes: body[body.startIndex..<pipeIdx], encoding: .utf8)?.first
        else { return }

        let payload = body[body.index(after: pipeIdx)...]
        messageSubject.send(IncomingMessage(namespace: nsChar, payload: Data(payload)))
    }
}

enum ProtocolError: Error {
    case ackTimeout
}
