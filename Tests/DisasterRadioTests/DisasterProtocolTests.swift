import XCTest
import Combine
@testable import DisasterRadio

// A mock transport that lets tests push raw bytes through the protocol stack.
final class MockTransport: DisasterTransport {
    private let stateSubject = CurrentValueSubject<TransportState, Never>(.connected)
    private let receivedSubject = PassthroughSubject<Data, Never>()

    var statePublisher: AnyPublisher<TransportState, Never> { stateSubject.eraseToAnyPublisher() }
    var receivedDataPublisher: AnyPublisher<Data, Never> { receivedSubject.eraseToAnyPublisher() }

    var sentData: [Data] = []

    func connect() {}
    func disconnect() {}
    func send(_ data: Data) { sentData.append(data) }

    func inject(_ data: Data) { receivedSubject.send(data) }
}

final class DisasterProtocolTests: XCTestCase {

    var proto: DisasterProtocol!
    var transport: MockTransport!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        proto = DisasterProtocol()
        transport = MockTransport()
        cancellables = []
        proto.bind(to: transport)
    }

    // MARK: - Sending

    func test_send_framesMessageWithIDAndNamespace() {
        proto.send(namespace: "c", payload: "hello")

        XCTAssertEqual(transport.sentData.count, 1)
        let data = transport.sentData[0]
        // First 2 bytes: message ID (UInt16 LE, starts at 0)
        XCTAssertEqual(data[0], 0x00)
        XCTAssertEqual(data[1], 0x00)
        // Remaining bytes: "c|hello"
        let body = String(data: data.dropFirst(2), encoding: .utf8)
        XCTAssertEqual(body, "c|hello")
    }

    func test_send_incrementsMessageID() {
        proto.send(namespace: "c", payload: "first")
        proto.send(namespace: "c", payload: "second")

        let id0 = UInt16(transport.sentData[0][0]) | (UInt16(transport.sentData[0][1]) << 8)
        let id1 = UInt16(transport.sentData[1][0]) | (UInt16(transport.sentData[1][1]) << 8)
        XCTAssertEqual(id1, id0 + 1)
    }

    // MARK: - Receiving

    func test_receive_parsesNamespaceAndPayload() async {
        let expectation = expectation(description: "message received")
        var received: IncomingMessage?

        proto.messagePublisher.sink { msg in
            received = msg
            expectation.fulfill()
        }.store(in: &cancellables)

        var data = Data([0x00, 0x00])
        data.append(contentsOf: "c|hello world".utf8)
        transport.inject(data)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(received?.namespace, "c")
        XCTAssertEqual(String(data: received!.payload, encoding: .utf8), "hello world")
    }

    func test_receive_ignoresMessagesTooShort() async {
        let expectation = expectation(description: "no message")
        expectation.isInverted = true

        proto.messagePublisher.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        transport.inject(Data([0x00, 0x00]))

        await fulfillment(of: [expectation], timeout: 0.2)
    }

    func test_receive_ignoresMessageWithNoNamespace() async {
        let expectation = expectation(description: "no message")
        expectation.isInverted = true

        proto.messagePublisher.sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        var data = Data([0x00, 0x00])
        data.append(contentsOf: "justtext".utf8)
        transport.inject(data)

        await fulfillment(of: [expectation], timeout: 0.2)
    }

    // MARK: - ACK

    func test_send_withCallback_stillSendsData() {
        proto.send(namespace: "c", payload: "hi") { _ in }
        XCTAssertEqual(transport.sentData.count, 1)
        let body = String(data: transport.sentData[0].dropFirst(2), encoding: .utf8)
        XCTAssertEqual(body, "c|hi")
    }

    func test_ackPacket_hasCorrectFormat() {
        // Verify the ACK we'd expect from the firmware matches [2-byte id][!]
        let id: UInt16 = 42
        var ack = Data()
        var idLE = id.littleEndian
        ack.append(contentsOf: withUnsafeBytes(of: &idLE, Array.init))
        ack.append(UInt8(ascii: "!"))
        XCTAssertEqual(ack.count, 3)
        XCTAssertEqual(ack[0], 42)
        XCTAssertEqual(ack[1], 0)
        XCTAssertEqual(ack[2], UInt8(ascii: "!"))
    }

    // MARK: - Multiple namespaces

    func test_receive_routeNamespace() async {
        let expectation = expectation(description: "route message received")
        var received: IncomingMessage?

        proto.messagePublisher.sink { msg in
            received = msg
            expectation.fulfill()
        }.store(in: &cancellables)

        var data = Data([0x01, 0x00])
        data.append(contentsOf: "r|".utf8)
        data.append(contentsOf: [0xFF, 0x00])
        transport.inject(data)

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(received?.namespace, "r")
    }
}
