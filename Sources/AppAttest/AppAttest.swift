import Crypto
import Foundation
import PotentCBOR
import X509

public struct AppAttest: Sendable {
  public var teamId: String
  public var bundleId: String

  public init(
    teamId: String,
    bundleId: String
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
  }
}
