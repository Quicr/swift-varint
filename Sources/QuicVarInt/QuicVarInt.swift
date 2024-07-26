import Foundation

enum VarIntError: Error {
    case empty
}

/// Implementation of QUIC's Variable Length Integer per RFC9000.
struct VarInt: UnsignedInteger {
    typealias Words = UInt64.Words
    typealias IntegerLiteralType = UInt64
    static let min: VarInt = 0
    static let max: VarInt = (1 << 62) - 1
    
    let words: Words
    let bitWidth: Int
    let trailingZeroBitCount: Int
    private let value: UInt64

    init<T>(_ source: T) where T : BinaryInteger {
        self.value = .init(source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }

    init<T>(clamping source: T) where T : BinaryInteger {
        guard source <= Self.max.value else {
            self.value = Self.max.value
            self.bitWidth = Self.calculateBitWidth(self.value)
            self.words = self.value.words
            self.trailingZeroBitCount = self.value.trailingZeroBitCount
            return
        }
        self.value = UInt64(clamping: source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
        guard source <= Self.max.value else {
            self.value = Self.max.value
            self.bitWidth = Self.calculateBitWidth(self.value)
            self.words = self.value.words
            self.trailingZeroBitCount = self.value.trailingZeroBitCount
            return
        }
        self.value = UInt64(truncatingIfNeeded: source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }

    init?<T>(exactly source: T) where T : BinaryInteger {
        guard let parsed = UInt64(exactly: source) else {
            return nil
        }
        self.value = parsed
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }

    init(integerLiteral value: UInt64) {
        self.value = value
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }

    init?<T>(exactly source: T) where T : BinaryFloatingPoint {
        guard let exactly = UInt64(exactly: source) else {
            return nil
        }
        self.value = exactly
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }

    init<T>(_ source: T) where T : BinaryFloatingPoint {
        self.value = UInt64(source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init(fromWire data: Data) throws {
        guard let firstByte = data.first else {
            throw VarIntError.empty
        }
        let prefix = firstByte >> 6
        let length = 1 << prefix
        print(length)
        var value = UInt64(firstByte) & 0x3f
        for index in 1..<length {
            value = (value << 8) + UInt64(data[index])
        }
        self.init(integerLiteral: value)
    }
    
    func toWireFormat() throws -> Data {
        switch self.bitWidth {
        case 8:
            var value = UInt8(self.value)
            value |= (UInt8(0b00).bigEndian)
            return .init(bytes: &value, count: MemoryLayout<UInt8>.size)
        case 16:
            var value = UInt16(self.value)
            value |= (UInt16(0b01).bigEndian)
            return .init(bytes: &value, count: MemoryLayout<UInt16>.size)
        case 32:
            var value = UInt32(self.value)
            value |= (UInt32(0b10).bigEndian)
            return .init(bytes: &value, count: MemoryLayout<UInt32>.size)
        case 64:
            var value = UInt64(self.value)
            value |= (UInt64(0b11).bigEndian)
            return .init(bytes: &value, count: MemoryLayout<UInt64>.size)
        default:
            fatalError()
        }
    }
    
    private func makeRepresentation(width: Int) -> any UnsignedInteger {
        switch width {
        case 1:
            UInt8()
        case 2:
            UInt16()
        case 3:
            UInt32()
        case 4:
            UInt64()
        default:
            fatalError()
        }
    }

    func hash(into hasher: inout Hasher) {
        self.value.hash(into: &hasher)
    }

    private static func calculateBitWidth(_ value: UInt64) -> Int {
        let oneByteMax: UInt64 = (1 << 6) - 1
        let twoByteMax: UInt64 = (1 << 14) - 1
        let fourByteMax: UInt64 = (1 << 30) - 1
        let eightByteMax: UInt64 = (1 << 62) - 1
        switch value {
        case 0...oneByteMax:
            return 8
        case (oneByteMax + 1)...twoByteMax:
            return 16
        case (twoByteMax + 1)...fourByteMax:
            return 32
        case (fourByteMax + 1)...eightByteMax:
            return 64
        default:
            fatalError("BitWidth")
        }
    }

    static func / (lhs: VarInt, rhs: VarInt) -> VarInt {
        .init(lhs.value / rhs.value)
    }

    static func % (lhs: VarInt, rhs: VarInt) -> VarInt {
        .init(lhs.value % rhs.value)
    }

    static func %= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs % rhs)
    }

    static func * (lhs: VarInt, rhs: VarInt) -> VarInt {
        .init(lhs.value * rhs.value)
    }

    static func &= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs.value & rhs.value)
    }

    static func |= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs.value | rhs.value)
    }

    static func ^= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs.value ^ rhs.value)
    }

    static func *= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs * rhs)
    }
    
    static func /= (lhs: inout VarInt, rhs: VarInt) {
        lhs = .init(lhs / rhs)
    }

    static func + (lhs: VarInt, rhs: VarInt) -> VarInt {
        .init(lhs.value + rhs.value)
    }

    static func - (lhs: VarInt, rhs: VarInt) -> VarInt {
        .init(lhs.value - rhs.value)
    }
    
    static prefix func ~ (x: VarInt) -> VarInt {
        .init(~x.value)
    }

    static func <<= <RHS>(lhs: inout VarInt, rhs: RHS) where RHS : BinaryInteger {
        var value = lhs.value
        value <<= rhs
        lhs = .init(value)
    }

    static func >>= <RHS>(lhs: inout VarInt, rhs: RHS) where RHS : BinaryInteger {
        var value = lhs.value
        value >>= rhs
        lhs = .init(value)
    }

    static func == (lhs: VarInt, rhs: VarInt) -> Bool {
        lhs.value == rhs.value
    }
}
