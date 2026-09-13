import Foundation

public struct Assertion: Decodable, Sendable, Hashable {
  public var signature: Data
  public var authenticatorData: AuthenticatorData
}

extension Assertion {
  public struct AuthenticatorData: Decodable, Sendable, Hashable {
    public let rawData: Data
    /// "\(appIDPrefix).\(bundleId)"  SHA256 hash data
    public let relyingPartyId: Data
    public let counter: UInt32
    /// The authenticator extensions App Attest appends on iOS 27 and later, or `nil` on
    /// earlier versions.
    public let extensions: AppAttestExtensions?

    private enum CodingKeys: String, CodingKey {
      case replyingPartyId
      case counter
      case extensions
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      let data = try container.decode(Data.self)
      guard data.count >= 37 else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Authenticator data is too short."
        )
      }
      self.rawData = data
      // 32 bytes
      self.relyingPartyId = data[0..<32]
      // 4 bytes "\0\0\0\0" -> 0
      self.counter = data[33..<37].reduce(0) { value, byte in
        value << 8 | UInt32(byte)
      }
      // On iOS 27 and later the extension map follows the counter.
      self.extensions = AppAttestExtensions(
        trailingBytes: data[37...],
        skippedItems: 0
      )
    }
  }
}
