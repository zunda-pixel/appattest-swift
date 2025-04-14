import AppAttest
import Foundation
import Testing

struct Request {
  var teamId: String
  var bundleId: String
  var environment: Environment
  var challenge: Data
  var keyId: String
  var attestation: Data
  var assertion: Data
  var bodyData: Data

  init(
    teamId: String,
    bundleId: String,
    environment: Environment,
    challenge: String,
    keyId: String,
    attestation: String,
    assertion: String,
    bodyData: String
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
    self.environment = environment
    self.challenge = Data(base64Encoded: challenge)!
    self.keyId = keyId
    self.attestation = Data(base64Encoded: attestation)!
    self.assertion = Data(base64Encoded: assertion)!
    self.bodyData = Data(base64Encoded: bodyData)!
  }
}

func verifyAttestationAndAssertion(request: Request) async throws {
  let appAttest = AppAttest(
    teamId: request.teamId,
    bundleId: request.bundleId,
    environment: request.environment
  )

  let attestation = try await appAttest.verifyAttestation(
    challenge: request.challenge,
    keyId: request.keyId,
    attestation: request.attestation
  )

  try appAttest.verifyAssertion(
    assertion: request.assertion,
    payload: request.bodyData,
    certificate: attestation.statement.credentialCertificate,
    counter: attestation.authenticatorData.counter
  )
}
