import Crypto
import Foundation
import PotentCBOR
import X509

public struct AppAttest: Sendable {
  public var appIDPrefix: String
  public var bundleId: String
  public var environment: Environment

  @available(*, deprecated, message: "Use appIDPrefix instead.")
  public var teamId: String {
    get { appIDPrefix }
    set { appIDPrefix = newValue }
  }

  public init(
    appIDPrefix: String,
    bundleId: String,
    environment: Environment
  ) {
    self.appIDPrefix = appIDPrefix
    self.bundleId = bundleId
    self.environment = environment
  }

  @available(*, deprecated, message: "Use init(appIDPrefix:bundleId:environment:) instead.")
  public init(
    teamId: String,
    bundleId: String,
    environment: Environment
  ) {
    self.init(
      appIDPrefix: teamId,
      bundleId: bundleId,
      environment: environment
    )
  }
}
