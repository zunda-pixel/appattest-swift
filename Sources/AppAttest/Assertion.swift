import Foundation

public struct Assertion: Decodable, Sendable, Hashable {
  public var signature: Data
  public var authenticatorData: AuthenticatorData
}

extension Assertion {
  public struct AuthenticatorData: Decodable, Sendable, Hashable {
    public let rawData: Data
    /// "\(teamId).\(bundleId)"  SHA256 hash data
    public let relyingPartyId: Data
    public let counter: UInt32
    
    private enum CodingKeys: String, CodingKey {
      case replyingPartyId
      case counter
    }
    
    public init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      let data = try container.decode(Data.self)
      self.rawData = data
      // 32 bytes
      self.relyingPartyId = data[0..<32]
      // 4 bytes "\0\0\0\0" -> 0
      self.counter = data[33..<37].reduce(0) { value, byte in
        value << 8 | UInt32(byte)
      }
    }
  }
}
