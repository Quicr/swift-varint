import XCTest
@testable import QuicVarInt

final class MathTests: XCTestCase {
    func test() {
        XCTAssertEqual(VarInt(2) + 2, 4)
        XCTAssertEqual(VarInt(2) - 2, 0)
        XCTAssertEqual(VarInt(2) * 4, 8)
        XCTAssertEqual(VarInt(8) / 2, 4)

        let randomUInt64 = UInt64.random(in: 0..<UInt64(VarInt.max))
        let randomVarInt = VarInt(randomUInt64)
        let anotherRandomUInt64 = UInt64.random(in: 0..<randomUInt64)
        let anotherRandomVarInt = VarInt(anotherRandomUInt64)

        let uintMaths = randomUInt64 - anotherRandomUInt64
        let varIntMaths = randomVarInt - anotherRandomVarInt
        XCTAssertEqual(uintMaths, UInt64(varIntMaths))
    }
}
