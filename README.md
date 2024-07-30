# QuicVarInt

RFC9000 compliant Swift implementation of QUIC's variable length integer, conforming to Swift's `UnsignedInteger` protocol. 

QuicVarInt has no dependencies, although there are optional extensions for working with `Data` if `Foundation` is available.

## Usage

`VarInt` can be used like any other `UnsignedInteger` with additional capabilities for encode/decode.

```swift
import QuicVarInt

// Literal support.
let original: VarInt = 25

// Maths
let plusOne = a + 1

// Encode to wire format, allocating storage for you.
let buffer = try plusOne.toWireFormat()
// Or pass your own buffer.
try plusOne.toWireFormat(into: yourBuffer)

// Decode from wire format.
let decoded = VarInt(fromWire: buffer)
print(decoded) // 25

// If you have `Foundation`, the above APIs can also take/return a `Data` buffer.
```

## Using in your project

Add to your `Package.swift` with something like the following:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
  name: "MyPackage",
  dependencies: [
    .package(
      url: "https://github.com/RichLogan/QuicVarInt.git", 
    )
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: [
        .product(name: "QuicVarInt", package: "QuicVarInt")
      ]
    )
  ]
)
```

## Development

- Usual swift tooling workflow, `swift build` and `swift test`. 
- A pre-commit hook is setup for SwiftLint, install using `pre-commit install`. 