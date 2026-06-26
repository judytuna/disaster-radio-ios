import XCTest
@testable import DisasterRadio

@MainActor
final class RouteParserTests: XCTestCase {

    // AppState.parseRoutes is the method under test.
    // We call it via a fresh AppState instance.
    var appState: AppState!

    override func setUp() {
        appState = AppState()
    }

    func test_emptyData_returnsEmptyArray() {
        let result = appState.parseRoutes(Data())
        XCTAssertTrue(result.isEmpty)
    }

    func test_dataShorterThanOneEntry_returnsEmpty() {
        let result = appState.parseRoutes(Data(repeating: 0, count: 15))
        XCTAssertTrue(result.isEmpty)
    }

    func test_oneEntry_parsesCorrectly() {
        // 16 bytes: 12 MAC + 2 hops LE + 2 metric LE
        var entry = Data(count: 16)
        // MAC: 00:11:22:33:44:55:66:77:88:99:AA:BB
        let mac: [UInt8] = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xAA, 0xBB]
        entry.replaceSubrange(0..<12, with: mac)
        // hops = 3 (LE: 0x03 0x00)
        entry[12] = 0x03
        entry[13] = 0x00
        // metric = 512 (LE: 0x00 0x02)
        entry[14] = 0x00
        entry[15] = 0x02

        let result = appState.parseRoutes(entry)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].mac, "00:11:22:33:44:55:66:77:88:99:aa:bb")
        XCTAssertEqual(result[0].hops, 3)
        XCTAssertEqual(result[0].metric, 512)
    }

    func test_twoEntries_parsesBoth() {
        let entry = Data(repeating: 0xAB, count: 16)
        let data = entry + entry

        let result = appState.parseRoutes(data)
        XCTAssertEqual(result.count, 2)
    }

    func test_extraBytesAtEnd_areIgnored() {
        // 16 bytes (one full entry) + 5 leftover bytes
        let data = Data(repeating: 0x00, count: 21)
        let result = appState.parseRoutes(data)
        XCTAssertEqual(result.count, 1)
    }

    func test_hopsLargeValue_parsedAsLittleEndian() {
        var entry = Data(count: 16)
        // hops = 0x0102 = 258 in LE: [0x02, 0x01]
        entry[12] = 0x02
        entry[13] = 0x01

        let result = appState.parseRoutes(entry)
        XCTAssertEqual(result[0].hops, 258)
    }

    func test_allZeroMac_formatsCorrectly() {
        let entry = Data(count: 16)
        let result = appState.parseRoutes(entry)
        XCTAssertEqual(result[0].mac, "00:00:00:00:00:00:00:00:00:00:00:00")
    }
}
