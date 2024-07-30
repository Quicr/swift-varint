#if canImport(Foundation)
import XCTest
@testable import QuicVarInt
import Foundation

final class QuicVarIntFoundationTests: XCTestCase {
    func testEightByte() throws {
        try test(UInt64(0xc2197c5eff14e88c), 151_288_809_941_952_652)
    }

    func testFourByte() throws {
        try test(UInt32(0x9d7f3e7d), 494_878_333)
    }

    func testTwoByte() throws {
        try test(UInt16(0x7bbd), 15_293)
    }

    func testOneByte() throws {
        try test(UInt8(0x25), 37)
    }

    func testTwoByteOneByteValue() throws {
        try test(UInt16(0x4025), 37, encode: false)
    }

    private func test<T: Allowed>(_ value: T, _ expected: VarInt, encode: Bool = true) throws {
        // Get the test data as bytes.
        var copy = value.bigEndian
        let networkBytes = Data(bytes: &copy, count: MemoryLayout<T>.size)

        // Get the VarInt stored in network bytes, and compare to expected value.
        let decoded = try VarInt.fromData(fromWire: networkBytes)
        XCTAssertEqual(expected, decoded)

        // Ensure the encoded result gives the same bytes as the test data.
        guard encode else { return }
        var buffer = Data(count: decoded.encodedBitWidth / 8)
        try decoded.toWireFormat(into: &buffer)
        XCTAssert(buffer.elementsEqual(networkBytes))
    }
}
#endif
