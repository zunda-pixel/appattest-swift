public struct AppAttest: Sendable {
  public var appIDPrefix: String
  public var bundleId: String
  public var environment: Environment

  public init(
    appIDPrefix: String,
    bundleId: String,
    environment: Environment
  ) {
    self.appIDPrefix = appIDPrefix
    self.bundleId = bundleId
    self.environment = environment
  }
}
