import AppAttest
import Crypto
import DeviceCheck
import Foundation
import Testing

struct Request {
  var teamId: String
  var bundleId: String
  var challenge: Data
  var keyId: String
  var attestation: Data
  var assertion: Data
  var bodyData: Data
  
  init(
    teamId: String,
    bundleId: String,
    challenge: String,
    keyId: String,
    attestation: String,
    assertion: String,
    bodyData: String
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
    self.challenge = Data(base64Encoded: challenge)!
    self.keyId = keyId
    self.attestation = Data(base64Encoded: attestation)!
    self.assertion = Data(base64Encoded: assertion)!
    self.bodyData = Data(base64Encoded: bodyData)!
  }
}

func verifyAttestationAndAssersion(request: Request) async throws {
  let appAttest = AppAttest(
    teamId: request.teamId,
    bundleId: request.bundleId
  )
  
  let attestatin = try await appAttest.verifyAttestation(
    challenge: request.challenge,
    keyId: Data(request.keyId.utf8),
    attestation: request.attestation,
    environment: .development
  )

  try appAttest.verifyAsssertion(
    assertion: request.assertion,
    payload: request.bodyData,
    certificate: attestatin.statement.credetialCertificate,
    counter: attestatin.authenticatorData.counter
  )
}
