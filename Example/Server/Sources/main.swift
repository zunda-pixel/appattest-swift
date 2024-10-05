import Hummingbird
import Foundation
import Crypto
import AppAttest

let appAttest = AppAttest(
  teamId: <#TEAM_ID#>,
  bundleId: <#BUNDLE_ID#>,
  environment: .development
)
let router = Router()

router.get("challenge") { _, _ -> ByteBuffer in
  let challenge = Data(AES.GCM.Nonce())
  struct Body: Encodable {
    var challenge: Data
  }
  let body = Body(challenge: challenge)
  let bodyData = try JSONEncoder().encode(body)
  
  return ByteBuffer(data: bodyData)
}

router.post("createUser") {
  request,
  context -> ByteBuffer in
  struct Payload: Codable {
    let challenge: Data
    let keyId: String
    let attestaion: Data
    let assertion: Data
    let body: Data
  }

  let payload = try await request.decode(
    as: Payload.self,
    context: context
  )
  
  let attestation = try await appAttest.verifyAttestation(
    challenge: payload.challenge,
    keyId: payload.keyId,
    attestation: payload.attestaion
  )
  
  try appAttest.verifyAsssertion(
    assertion: payload.assertion,
    payload: payload.body,
    certificate: attestation.statement.credetialCertificate,
    counter: attestation.authenticatorData.counter
  )
  
  struct Body: Codable {
    let name: String
    let age: Int
  }
  
  let body = try JSONDecoder().decode(Body.self, from: payload.body)
  
  print(body)
  
  return ByteBuffer(data: payload.body)
}

let app = Application(
  router: router,
  configuration: .init(
    address: .hostname("0.0.0.0", port: 8080)
  )
)

try await app.runService()
