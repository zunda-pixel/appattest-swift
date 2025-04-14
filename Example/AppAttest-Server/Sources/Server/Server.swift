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

  static func main() async throws {
    let appAttest = AppAttest(
      teamId: <#TEAM_ID#>,
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

      try verifyChallenge(
        userId: payload.userId,
        sessionId: payload.sessionId,
        challengeData: payload.challenge
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

      let newUser = try JSONDecoder().decode(User.self, from: payload.body)

      users.append(newUser)

      return ByteBuffer(data: payload.body)
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
      throw AppAttestError.notFoundChallenge
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
  case notFoundChallenge
  case challengeExpired
}
