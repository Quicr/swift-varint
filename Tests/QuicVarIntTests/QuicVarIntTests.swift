import XCTest
@testable import QuicVarInt

protocol Allowed: FixedWidthInteger { }
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
        try test(UInt16(0x4025), 37, encode: false)
    }

    private func test<T: Allowed>(_ value: T, _ expected: VarInt, encode: Bool = true) throws {
        // Get the test data as bytes.
        let networkBytes = UnsafeMutableRawBufferPointer.allocate(byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<UInt8>.alignment)
        defer { networkBytes.deallocate() }
        networkBytes.storeBytes(of: value.bigEndian, as: T.self)

        // Get the VarInt stored in network bytes, and compare to expected value.
        let decoded = try VarInt(fromWire: .init(networkBytes))
        XCTAssertEqual(expected, decoded)

        // Ensure the encoded result gives the same bytes as the test data.
        guard encode else { return }
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: decoded.encodedBitWidth / 8,
                                                            alignment: MemoryLayout<UInt8>.alignment)
        defer { buffer.deallocate() }
        try decoded.toWireFormat(into: buffer)
        XCTAssert(buffer.elementsEqual(networkBytes))
    }
}
