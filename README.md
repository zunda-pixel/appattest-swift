# appattest-swift

## 1. [Server] Generate challenge and return to Client(iOS)

```swift
import Foundation
import Crypt

let challenge = Data(AES.GCM.Nonce())
```

## 2. [Client(iOS)] Send Data to Server

```swift
import Crypto
import DeviceCheck
import Foundation

func sendData(challenge: Data) async throws {
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

  return (attestation, assertion, bodyData)
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

func verifyAndHandleBody(
  attestation: Data,
  assertion: Data,
  bodyData: Data
) async throws {
  let teamId = ProcessInfo.processInfo.environment["TEAM_ID"]! // PH3HCZ4AK6
  let bundleId = ProcessInfo.processInfo.environment["BUNDLE_ID"]! // com.example.memo

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
  
  print(body.name)
  print(body.age)
}
```
