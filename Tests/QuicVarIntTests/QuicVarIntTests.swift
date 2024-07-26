import XCTest
@testable import QuicVarInt

protocol Allowed { }
extension UInt8: Allowed { }
extension UInt16: Allowed { }
extension UInt32: Allowed { }
extension UInt64: Allowed { }

final class QuicVarIntTests: XCTestCase {
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
        try test(UInt16(0x4025), 37)
    }

    private func test<T: Allowed>(_ value: T, _ expected: VarInt) throws {
        // Get the test data as bytes.
        var copy = value
        let binary = Data(bytesNoCopy: &copy, count: MemoryLayout<T>.size, deallocator: .none)

        // Decode a VarInt from the test data and check equality.
        let decoded = try VarInt(fromWire: binary)
        XCTAssertEqual(expected, decoded)

        // Ensure the encoded result gives the same bytes as the test data.
        let encoded = try decoded.toWireFormat()
        XCTAssertEqual(encoded, binary)
    }
}
