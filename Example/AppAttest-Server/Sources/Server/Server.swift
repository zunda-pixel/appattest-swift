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
struct Server {
  static func main() async throws {
    try await App().run()
  }
}

actor App {
  var users: [User] = []
  var challenges: [Challenge] = []
  var countersByKeyId: [String: UInt32] = [:]

  func run() async throws {
    let appAttest = AppAttest(
      appIDPrefix: <#APP_ID_PREFIX#>,
      bundleId: <#BUNDLE_ID#>,
      environment: .development
    )

    let router = Router()

    router.get("challenge") { request, _ -> ByteBuffer in
      guard
        let userIdValue = request.uri.queryParameters["userId"],
        let sessionIdValue = request.uri.queryParameters["sessionId"],
        let userId = UUID(uuidString: String(userIdValue)),
        let sessionId = UUID(uuidString: String(sessionIdValue))
      else {
        throw HTTPError(.badRequest, message: "Invalid userId or sessionId")
      }

      let challenge = Challenge(
        userId: userId,
        sessionId: sessionId,
        expiredAt: .now.addingTimeInterval(5 * 60),
        value: Data(AES.GCM.Nonce())
      )

      await self.appendChallenge(challenge)

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

      try await self.verifyChallenge(
        userId: payload.userId,
        sessionId: payload.sessionId,
        challengeData: clientData.challenge
      )

      let attestation = try await appAttest.verifyAttestation(
        challenge: clientData.challenge,
        keyId: clientData.keyId,
        attestation: payload.attestation
      )

      try await self.verifyAssertionAndStoreCounter(
        keyId: clientData.keyId,
        defaultCounter: attestation.authenticatorData.counter
      ) { previousCounter in
        try appAttest.verifyAssertion(
          assertion: payload.assertion,
          payload: payload.clientData,
          certificate: attestation.statement.credentialCertificate,
          counter: previousCounter
        )
      }

      let newUser = try JSONDecoder().decode(User.self, from: clientData.body)

      await self.appendUser(newUser)

      return ByteBuffer(data: clientData.body)
    }

    router.get("users") { _, _ -> ByteBuffer in
      let users = await self.allUsers()
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

  func verifyChallenge(userId: UUID, sessionId: UUID, challengeData: Data) throws {
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

  func appendChallenge(_ challenge: Challenge) {
    challenges.append(challenge)
  }

  func verifyAssertionAndStoreCounter(
    keyId: String,
    defaultCounter: UInt32,
    verify: (UInt32) throws -> UInt32
  ) rethrows {
    let previousCounter = countersByKeyId[keyId] ?? defaultCounter
    let counter = try verify(previousCounter)
    countersByKeyId[keyId] = counter
  }

  func appendUser(_ user: User) {
    users.append(user)
  }

  func allUsers() -> [User] {
    users
  }
}

enum AppAttestError: Error {
  case challengeNotFound
  case challengeExpired
}
