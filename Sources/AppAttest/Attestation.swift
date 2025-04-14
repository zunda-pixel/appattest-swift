import Foundation

public struct Attestation: Decodable, Sendable, Hashable {
  public var format: String
  public var statement: Statement
  public var authenticatorData: AuthenticatorData

  private enum CodingKeys: String, CodingKey {
    case format = "fmt"
    case statement = "attStmt"
    case authenticatorData = "authData"
  }
}

extension Attestation {
  public struct AuthenticatorData: Decodable, Sendable, Hashable {
    public let rawData: Data
    /// "\(teamId).\(bundleId)"  SHA256 hash data
    public let relyingPartyId: Data
    public let counter: UInt32
    public let environment: Environment
    public let credentialId: Data

    private enum CodingKeys: String, CodingKey {
      case replyingPartyId
      case counter
      case environment = "aaguid"
      case credentialId
    }

    // https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server#Verify-the-attestation
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
      // 16 bytes "\0\0\0\0appattest\0\0\0\0\0\0\0\0 " -> appattest
      let dataEnvironment = data[37..<53]
      if let environment = Environment(bytes: dataEnvironment) {
        self.environment = environment
      } else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription:
            "value is not a valid AAGUID: \(String(decoding: dataEnvironment, as: UTF8.self))"
        )
      }

      // 32 bytes KeyId
      self.credentialId = data[55..<87]
    }
  }
}
