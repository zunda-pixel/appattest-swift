import AppAttest
import Crypto
import Foundation
import Hummingbird

struct User: Codable {
  var name: String
  var age: Int
}

struct Challenge {
  var userId: UUID
  var sessionId: UUID
  var expiredAt: Date
  var value: Data
}

@main
actor App {
  static var users: [User] = []
  static var challenges: [Challenge] = []
  static var countersByKeyId: [String: UInt32] = [:]

  static func main() async throws {
    let appAttest = AppAttest(
      appIDPrefix: <#APP_ID_PREFIX#>,
      bundleId: <#BUNDLE_ID#>,
      environment: .development
    )

    let router = Router()

    router.get("challenge") { request, _ -> ByteBuffer in
      let userId = request.uri.queryParameters["userId"]!
      let sessionId = request.uri.queryParameters["sessionId"]!

      let challenge = Challenge(
        userId: UUID(uuidString: String(userId))!,
        sessionId: UUID(uuidString: String(sessionId))!,
        expiredAt: .now.addingTimeInterval(5 * 60),
        value: Data(AES.GCM.Nonce())
      )

      challenges.append(challenge)

      struct Body: Encodable {
        var challenge: Data
      }
      let body = Body(challenge: challenge.value)
      let bodyData = try JSONEncoder().encode(body)

      return ByteBuffer(data: bodyData)
    }

    router.post("createUser") { request, context -> ByteBuffer in
      struct Payload: Codable {
        let userId: UUID
        let sessionId: UUID
        let attestation: Data
        let assertion: Data
        let clientData: Data
      }

      struct AssertionClientData: Codable {
        let challenge: Data
        let keyId: String
        let body: Data
      }

      let payload = try await request.decode(
        as: Payload.self,
        context: context
      )
      let clientData = try JSONDecoder().decode(
        AssertionClientData.self,
        from: payload.clientData
      )

      try verifyChallenge(
        userId: payload.userId,
        sessionId: payload.sessionId,
        challengeData: clientData.challenge
      )

      let attestation = try await appAttest.verifyAttestation(
        challenge: clientData.challenge,
        keyId: clientData.keyId,
        attestation: payload.attestation
      )

      let previousCounter = countersByKeyId[payload.keyId] ?? attestation.authenticatorData.counter
      let counter = try appAttest.verifyAssertion(
        assertion: payload.assertion,
        payload: payload.clientData,
        certificate: attestation.statement.credentialCertificate,
        counter: previousCounter
      )
      countersByKeyId[payload.keyId] = counter

      let newUser = try JSONDecoder().decode(User.self, from: clientData.body)

      users.append(newUser)

      return ByteBuffer(data: clientData.body)
    }

    router.get("users") { _, _ -> ByteBuffer in
      let body = try JSONEncoder().encode(users)
      return ByteBuffer(data: body)
    }

    let app = Application(
      router: router,
      configuration: .init(
        address: .hostname("0.0.0.0", port: 8080)
      )
    )

    try await app.runService()
  }

  static func verifyChallenge(userId: UUID, sessionId: UUID, challengeData: Data) throws {
    guard
      let challenge = challenges.first(where: {
        $0.userId == userId && $0.sessionId == sessionId && $0.value == challengeData
      })
    else {
      throw AppAttestError.challengeNotFound
    }

    guard Date.now <= challenge.expiredAt else {
      throw AppAttestError.challengeExpired
    }

    challenges.removeAll {
      $0.userId == userId && $0.sessionId == sessionId && $0.value == challengeData
    }
  }
}

enum AppAttestError: Error {
  case challengeNotFound
  case challengeExpired
}
