import AppAttest
import Crypto
import DeviceCheck
import Foundation
import Testing

struct Body: Codable {
  let name: String
  let age: Int
  let challenge: Data
  let keyId: String
}

func clientCode(challenge: Data) async throws -> (
  attestation: Data,
  assertion: Data,
  bodyData: Data
) {
  let service = DCAppAttestService.shared
  let keyId = try await service.generateKey()

  let attestation = try await service.attestKey(
    keyId,
    clientDataHash: Data(SHA256.hash(data: challenge))
  )

  let body = Body(
    name: "name1",
    age: 25,
    challenge: challenge,
    keyId: keyId
  )

  let bodyData = try JSONEncoder().encode(body)
  let assertion = try await service.generateAssertion(
    keyId,
    clientDataHash: Data(SHA256.hash(data: bodyData))
  )

  return (attestation, assertion, bodyData)
}

func serverCode(
  attestation: Data,
  assertion: Data,
  bodyData: Data
) async throws {
  var teamId = Bundle.main.infoDictionary!["AppIdentifierPrefix"]! as! String  // "PU5HXZ4FZ2",
  teamId.removeLast()

  let bundleId = Bundle.main.bundleIdentifier!  //"com.zunda.TestAppAttest"

  let appAttest = AppAttest(
    teamId: teamId,
    bundleId: bundleId
  )

  let body = try JSONDecoder().decode(Body.self, from: bodyData)

  let attestatin = try await appAttest.verifyAttestation(
    challenge: body.challenge,
    keyId: Data(body.keyId.utf8),
    attestation: attestation,
    environment: .development
  )

  try appAttest.verifyAsssertion(
    assertion: assertion,
    payload: bodyData,
    certificate: attestatin.statement.credetialCertificate,
    counter: attestatin.authenticatorData.counter
  )
}

@Test
func appAttest() async throws {
  #expect(DCAppAttestService.shared.isSupported)

  // Generate Challenge Value On Server
  let challeange = Data(AES.GCM.Nonce())
  // Generate Attestation Assertion, BodyData on Client(iOS)
  let (attestation, assertion, bodyData) = try await clientCode(challenge: challeange)
  // Verify Data on Server
  try await serverCode(
    attestation: attestation,
    assertion: assertion,
    bodyData: bodyData
  )
  // User Body on Server
  let body = try JSONDecoder().decode(Body.self, from: bodyData)
  print(body)
}
