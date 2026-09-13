# AppAttest

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fappattest-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/zunda-pixel/appattest-swift)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fzunda-pixel%2Fappattest-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/zunda-pixel/appattest-swift)


## 1. [Server] Generate challenge and return to Client(iOS)

```swift
import Foundation
import Crypto

@main
struct App {
  // DB or Server session data
  var challenges: [Challenge] = []

  mutating func generateChallenge(userId: UUID, sessionId: UUID) -> Data {
    let challenge = Challenge(
      userId: userId,
      sessionId: sessionId,
      expiredAt: Date.now.addingTimeInterval(5 * 60), // expired after 5 minutes.
      value: Data(AES.GCM.Nonce())
    )

    challenges.append(challenge)
    return challenge.value
  }
}

struct Challenge {
  var userId: UUID
  var sessionId: UUID
  var expiredAt: Date
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

  return (userId, sessionId, attestation, assertion, bodyData)
}

struct Body: Codable {
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
actor App {
  var challenges: [Challenge] = []
  var countersByKeyId: [String: UInt32] = [:]

  func verifyAndHandleBody(
    userId: UUID,
    sessionId: UUID,
    attestation: Data,
    assertion: Data,
    bodyData: Data
  ) async throws {
    let appIDPrefix = ProcessInfo.processInfo.environment["APP_ID_PREFIX"]! // PH3HCZ4AK6
    let bundleId = ProcessInfo.processInfo.environment["BUNDLE_ID"]! // com.example.memo
  
    let appAttest = AppAttest(
      appIDPrefix: appIDPrefix,
      bundleId: bundleId,
      environment: .development
    )
  
    let body = try JSONDecoder().decode(Body.self, from: bodyData)

    try verifyChallenge(
      userId: userId,
      sessionId: sessionId,
      challengeData: body.challenge
    )
    
    let attestation = try await appAttest.verifyAttestation(
      challenge: body.challenge,
      keyId: body.keyId,
      attestation: attestation
    )
  
    let previousCounter = countersByKeyId[body.keyId] ?? attestation.authenticatorData.counter
    let counter = try appAttest.verifyAssertion(
      assertion: assertion,
      payload: bodyData,
      certificate: attestation.statement.credentialCertificate,
      counter: previousCounter
    )
    countersByKeyId[body.keyId] = counter
    
    print(body.name)
    print(body.age)
  }

  func verifyChallenge(userId: UUID, sessionId: UUID, challengeData: Data) throws {
    guard let challenge = challenges.first(where: { $0.userId == userId && $0.sessionId == sessionId && $0.value == challengeData }) else {
      throw AppAttestError.challengeNotFound
    }

    guard Date.now <= challenge.expiredAt else {
      throw AppAttestError.challengeExpired
    }

    challenges.removeAll { $0.userId == userId && $0.sessionId == sessionId && $0.value == challengeData }
  }
}
```

## 4. [Server] Read the iOS 27 authenticator extensions

On iOS 27 and later, App Attest appends [authenticator extensions](https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide) to the authenticator data. They are exposed as `extensions`, which is `nil` whenever the authenticator data carries no readable extension map - every OS before iOS 27, but also any future map that renames or re-encodes either key. Treat the extensions as an additional signal rather than as a hard requirement.

```swift
let attestation = try await appAttest.verifyAttestation(
  challenge: body.challenge,
  keyId: body.keyId,
  attestation: attestation
)

if let extensions = attestation.authenticatorData.extensions {
  // `apple_validation_category_01`: how the OS validated the running app.
  switch extensions.validationCategory {
  case .appStore, .testFlight:
    break
  default:
    // Development, enterprise, Developer ID, locally signed, ...
    throw AppAttestError.unexpectedValidationCategory
  }

  // `apple_bundle_version_01`: the bundle version of the running app.
  print(extensions.bundleVersion)
}
```

Assertions carry the same extensions on `Assertion.AuthenticatorData.extensions`. Note that `verifyAssertion` returns only the counter, so reaching them means decoding the assertion yourself with `CBORDecoder().decode(Assertion.self, from: [UInt8](assertion))`. That decode performs no verification at all: only read those extensions after `verifyAssertion` has succeeded for the same bytes, otherwise `validationCategory` and `bundleVersion` are whatever the caller chose to send. The attestation extensions above are covered by the nonce that `verifyAttestation` checks, so prefer them.

> [!NOTE]
> The WebAuthn flags byte is not a reliable signal here. `ED` (extension data included) is set by iOS 27.0 but clear in the sample in Apple's validation guide, and iOS 27.0 sets `AT` on assertions that carry no attested credential data. The extensions are therefore located by the trailing CBOR rather than by the flags. The full authenticator data is still kept in `rawData` and used for nonce and signature verification.
