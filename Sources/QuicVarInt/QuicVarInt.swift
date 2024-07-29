enum VarIntError: Error {
    case empty
    case bufferTooSmall(Int)
}

/// Implementation of QUIC's Variable Length Integer per RFC9000.
struct VarInt: UnsignedInteger {
    typealias Words = UInt64.Words
    typealias IntegerLiteralType = UInt64
    static let min: VarInt = 0
    static let max: VarInt = VarInt(UInt64((1 << 62)) - 1)
    
    // Protocol conformances.
    let words: Words
    let bitWidth: Int
    let encodedBitWidth: Int
    let trailingZeroBitCount: Int
    
    // Internal value.
    private let value: UInt64
    
    init<T>(_ source: T) where T: BinaryInteger {
        self.value = .init(source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init<T>(clamping source: T) where T: BinaryInteger {
        let clamped: T
        if source > Self.max {
            clamped = T(Self.max)
        } else if source < Self.min {
            clamped = T(Self.min)
        } else {
            clamped = source
        }
        self.value = UInt64(clamping: clamped)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init<T>(truncatingIfNeeded source: T) where T: BinaryInteger {
        guard source <= Self.max.value else {
            self.value = Self.max.value
            self.bitWidth = Self.calculateBitWidth(self.value)
            self.encodedBitWidth = self.bitWidth + 2
            self.words = self.value.words
            self.trailingZeroBitCount = self.value.trailingZeroBitCount
            return
        }
        self.value = UInt64(truncatingIfNeeded: source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init?<T>(exactly source: T) where T: BinaryInteger {
        guard let parsed = UInt64(exactly: source) else {
            return nil
        }
        self.value = parsed
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init(integerLiteral value: UInt64) {
        self.value = value
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init?<T>(exactly source: T) where T: BinaryFloatingPoint {
        guard let exactly = UInt64(exactly: source) else {
            return nil
        }
        self.value = exactly
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init<T>(_ source: T) where T: BinaryFloatingPoint {
        self.value = UInt64(source)
        self.bitWidth = Self.calculateBitWidth(self.value)
        self.encodedBitWidth = self.bitWidth + 2
        self.words = self.value.words
        self.trailingZeroBitCount = self.value.trailingZeroBitCount
    }
    
    init(fromWire data: UnsafeRawBufferPointer) throws {
        // We need at least a byte to work with!
        guard let firstByte = data.first else {
            throw VarIntError.empty
        }
        // Top 2 bits are the encoded length.
        let first2Bits: UInt8 = firstByte >> 6
        // Decode the length.
        let length = 1 << first2Bits
        guard length <= data.count else {
            // We need at least length bytes given the length.
            throw VarIntError.bufferTooSmall(length)
        }
        
        switch length {
        case 1:
            let built: UInt8 = Self.build(data: data, length: length)
            self.init(integerLiteral: UInt64(built))
        case 2:
            let built: UInt16 = Self.build(data: data, length: length)
            self.init(integerLiteral: UInt64(built))
        case 4:
            let built: UInt32 = Self.build(data: data, length: length)
            self.init(integerLiteral: UInt64(built))
        case 8:
            let built: UInt64 = Self.build(data: data, length: length)
            self.init(integerLiteral: UInt64(built))
        default:
            fatalError()
        }
    }
    
    private static func build<T: FixedWidthInteger>(data: UnsafeRawBufferPointer, length: Int) -> T {
        guard let first = data.first else { fatalError() }
        var value = T(first & 0b00111111).bigEndian
        for index in 1..<length {
            value |= T(data[index]).bigEndian >> (8 * index)
        }
        return value.littleEndian
    }
    
    func toWireFormat(into: UnsafeMutableRawBufferPointer) throws {
        let requiredLength = self.bitWidth / 8
        guard into.count >= requiredLength else {
            throw VarIntError.bufferTooSmall(requiredLength)
        }
        switch self.bitWidth {
        case 6:
            into.storeBytes(of: UInt8(self.value), as: UInt8.self)
        case 14:
            let first = UInt8(truncatingIfNeeded: (self.value >> 8) | 0x40)
            into.storeBytes(of: first, as: UInt8.self)
            let second = UInt8(truncatingIfNeeded: self.value)
            into.storeBytes(of: second, toByteOffset: 1, as: UInt8.self)
        case 30:
            let first = UInt8(truncatingIfNeeded: (self.value >> 24) | 0x80)
            into.storeBytes(of: first, as: UInt8.self)
            let second = UInt8(truncatingIfNeeded: self.value >> 16)
            into.storeBytes(of: second, toByteOffset: 1, as: UInt8.self)
            let third = UInt8(truncatingIfNeeded: self.value >> 8)
            into.storeBytes(of: third, toByteOffset: 2, as: UInt8.self)
            let fourth = UInt8(truncatingIfNeeded: self.value)
            into.storeBytes(of: fourth, toByteOffset: 3, as: UInt8.self)
        case 62:
            let first = UInt8(truncatingIfNeeded: (self.value >> 56) | 0xC0)
            into.storeBytes(of: first, as: UInt8.self)
            let second = UInt8(truncatingIfNeeded: self.value >> 48)
            into.storeBytes(of: second, toByteOffset: 1, as: UInt8.self)
            let third = UInt8(truncatingIfNeeded: self.value >> 40)
            into.storeBytes(of: third, toByteOffset: 2, as: UInt8.self)
            let fourth = UInt8(truncatingIfNeeded: self.value >> 32)
            into.storeBytes(of: fourth, toByteOffset: 3, as: UInt8.self)
            let fifth = UInt8(truncatingIfNeeded: self.value >> 24)
            into.storeBytes(of: fifth, toByteOffset: 4, as: UInt8.self)
            let sixth = UInt8(truncatingIfNeeded: self.value >> 16)
            into.storeBytes(of: sixth, toByteOffset: 5, as: UInt8.self)
            let seventh = UInt8(truncatingIfNeeded: self.value >> 8)
            into.storeBytes(of: seventh, toByteOffset: 6, as: UInt8.self)
            let eighth = UInt8(truncatingIfNeeded: self.value)
            into.storeBytes(of: eighth, toByteOffset: 7, as: UInt8.self)
        default:
            fatalError()
        }
    }
    
    private static func calculateBitWidth(_ value: UInt64) -> Int {
        let oneByteMax: UInt64 = (1 << 6) - 1
        let twoByteMax: UInt64 = (1 << 14) - 1
        let fourByteMax: UInt64 = (1 << 30) - 1
        let eightByteMax: UInt64 = (1 << 62) - 1
        switch value {
        case 0...oneByteMax:
            return 6
        case (oneByteMax + 1)...twoByteMax:
            return 14
        case (twoByteMax + 1)...fourByteMax:
            return 30
        case (fourByteMax + 1)...eightByteMax:
            return 62
        default:
            fatalError("BitWidth")
        }
    }
}

// Operators.
extension VarInt {
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

    static func <<= <RHS>(lhs: inout VarInt, rhs: RHS) where RHS: BinaryInteger {
        var value = lhs.value
        value <<= rhs
        lhs = .init(value)
    }

    static func >>= <RHS>(lhs: inout VarInt, rhs: RHS) where RHS: BinaryInteger {
        var value = lhs.value
        value >>= rhs
        lhs = .init(value)
    }
}

extension VarInt: Hashable {
    func hash(into hasher: inout Hasher) {
        self.value.hash(into: &hasher)
    }

    static func == (lhs: VarInt, rhs: VarInt) -> Bool {
        lhs.value == rhs.value
    }
}

// Random.
extension VarInt {
    private static func rangeFrom(in range: ClosedRange<Self>) -> ClosedRange<UInt64> {
        return .init(uncheckedBounds: (range.lowerBound.value, range.upperBound.value))
    }
    
    static func random(in range: ClosedRange<Self>) -> Self {
        return .init(UInt64.random(in: rangeFrom(in: range)))
    }

    static func random<T: RandomNumberGenerator>(in range: ClosedRange<Self>, using: inout T) -> Self {
        return .init(UInt64.random(in: rangeFrom(in: range), using: &using))
    }
    
    private static func rangeFrom(in range: Range<Self>) -> Range<UInt64> {
        return .init(uncheckedBounds: (range.lowerBound.value, range.upperBound.value))
    }

    static func random(in range: Range<Self>) -> Self {
        return .init(UInt64.random(in: rangeFrom(in: range)))
    }

    static func random<T: RandomNumberGenerator>(in range: Range<Self>, using: inout T) -> Self {
        return .init(UInt64.random(in: rangeFrom(in: range), using: &using))
    }
}
