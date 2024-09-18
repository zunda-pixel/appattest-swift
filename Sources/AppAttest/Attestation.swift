public struct Attestation: Decodable {
  public var format: String
  public var statement: Statement
  public var authenticatorData: AuthenticatorData

  private enum CodingKeys: String, CodingKey {
    case format = "fmt"
    case statement = "attStmt"
    case authenticatorData = "authData"
  }
}
