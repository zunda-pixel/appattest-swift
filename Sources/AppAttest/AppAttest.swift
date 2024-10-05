import Crypto
import Foundation
import PotentCBOR
import X509

public struct AppAttest: Sendable {
  public var teamId: String
  public var bundleId: String
  public var environment: Environment

  public init(
    teamId: String,
    bundleId: String,
    environment: Environment
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
    self.environment = environment
  }
}
