#if canImport(Foundation)
import Foundation

extension VarInt {
    /// Copy the encoded VarInt bytes into the provided buffer.
    /// - Throws VarIntError.bufferTooSmall(required) if the provided buffer is too small.
    public func toWireFormat(into: inout Data) throws {
        try into.withUnsafeMutableBytes {
            try self.toWireFormat(into: $0)
        }
    }

    /// Return the encoded VarInt buffer ready to be written to the wire.
    /// - Returns Encoded bytes.
    public func toWireFormat() throws -> Data {
        var data = Data(capacity: self.encodedBitWidth * 8)
        try data.withUnsafeMutableBytes {
            try toWireFormat(into: $0)
        }
        return data
    }

    /// Create a VarInt from its encoded byte representation.
    /// - Parameter fromWire Data containing an RFC9000 encoded VarInt.
    /// - Throws A `VarIntError` if there is an issue with the provided buffer.
    public static func fromData(fromWire data: Data) throws -> VarInt {
        try data.withUnsafeBytes {
            return try .init(fromWire: $0)
        }
    }
}
#endif
