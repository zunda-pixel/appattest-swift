# AppAttest

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fappattest-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/zunda-pixel/appattest-swift)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fappattest-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/zunda-pixel/appattest-swift)


## 1. [Server] Generate challenge and return to Client(iOS)

```swift
import Foundation
import Crypt

@main
struct App {
  // DB or Server session data
  var challenges: [Challenge] = []

  mutating func generateChallenge(userId: UUID, sessionId: UUID) -> Data {
    let challenge = Challenge(
      userId: userId,
      sessionId: sessionId,
      expiredAt: Date.now.addingTimeInterval(5 * 60), // expired after 5 minites.
      value: Data(AES.GCM.Nonce())
    )

    challenges.append(challenge)
    return challenge.value
  }
}

struct Challnge {
  var userId: UUID
  var sessionId: UUID
  var expiredAt: Data
  var value: Data
}
```

## 2. [Client(iOS)] Send Data to Server

```swift
import Crypto
import DeviceCheck
import Foundation

func sendData(
  challenge: Data,
  userId: UUID,
  sessionId: UUID
) async throws {
  let service = DCAppAttestService.shared
  let keyId = try await service.generateKey()

  let attestation = try await service.attestKey(
    keyId,
    clientDataHash: Data(SHA256.hash(data: challenge))
  )

  let body = Body(
    userId: userId,
    sessionId: sessionId,
    name: "sample name",
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

struct Body: Codable {
  let sessionId: UUID
  let userId: UUID
  let name: String
  let age: Int
  let challenge: Data
  let keyId: String
}
```

## 3. [Server] Verify data and Handle Body

```swift
import AppAttest
import Foundation

@main
struct App {
  var challenges: [Challenge] = []

  func verifyAndHandleBody(
    attestation: Data,
    assertion: Data,
    bodyData: Data
  ) async throws {
    let teamId = ProcessInfo.processInfo.environment["TEAM_ID"]! // PH3HCZ4AK6
    let bundleId = ProcessInfo.processInfo.environment["BUNDLE_ID"]! // com.example.memo
  
    let appAttest = AppAttest(
      teamId: teamId,
      bundleId: bundleId,
      environment: .development
    )
  
    let body = try JSONDecoder().decode(Body.self, from: bodyData)

    try verifyChallnge(
      userId: body.userId,
      sessionId: body.sessionId,
      challenge: body.challenge
    )
    
    let attestatin = try await appAttest.verifyAttestation(
      challenge: body.challenge,
      keyId: body.keyId,
      attestation: attestation
    )
  
    try appAttest.verifyAsssertion(
      assertion: assertion,
      payload: bodyData,
      certificate: attestatin.statement.credetialCertificate,
      counter: attestatin.authenticatorData.counter
    )
    
    print(body.name)
    print(body.age)
  }

  func verifyChallnge(userId: UUID, sessionId: UUID, challenge: Data) throws {
    guard let challenge = challenges.first { $0.userId == userId && $0.sessionId == sessionId && $0.value == challenge } else {
      throw AppAttestError.notFoundChallenge
    }

    guard challenge.expiredAt <= Date.now else {
      throw AppAttestError.challengeExpired
    }

    challenges.removeAll  { $0.userId == userId && $0.sessionId == sessionId && $0.value == challenge }
  }
}
```
