import CryptoKit
import DeviceCheck
import HTTPTypes
import HTTPTypesFoundation

let baseUrl: URL = URL(string: <#BASE_URL#>)!

enum Client {
  static func createUser(
    body: Data
  ) async throws -> (Data, HTTPResponse) {
    let url = baseUrl.appending(path: "createUser")
    let request = HTTPRequest(
      method: .post,
      url: url
    )

    print("Preparing payload...")

    let payload = try await prepareData(body: body)

    let payloadData = try JSONEncoder().encode(payload)

    print("Uploadig payload...")

    return try await URLSession.shared.upload(
      for: request,
      from: payloadData
    )
  }

  static func getUsers() async throws -> [User] {
    let request = HTTPRequest(
      method: .get,
      url: baseUrl.appending(path: "users")
    )

    let (data, _) = try await URLSession.shared.data(
      for: request
    )

    return try JSONDecoder().decode([User].self, from: data)
  }

  static func getChallenge(
    userId: UUID,
    sessionId: UUID
  ) async throws -> Data {
    let url =
      baseUrl
      .appending(path: "challenge")
      .appending(queryItems: [
        .init(name: "userId", value: userId.uuidString),
        .init(name: "sessionId", value: sessionId.uuidString),
      ])
    let request = HTTPRequest(
      method: .get,
      url: url
    )

    let (data, _) = try await URLSession.shared.data(for: request)

    struct Response: Codable {
      let challenge: Data
    }

    let response = try JSONDecoder().decode(Response.self, from: data)

    return response.challenge
  }

  static private func prepareData(body: Data) async throws -> Payload {
    let keyId = try await DCAppAttestService.shared.generateKey()
    let userId = UUID()
    let sessionId = UUID()

    print("Request challenge userId: \(userId), sessionId: \(sessionId)")
    let challenge = try await getChallenge(
      userId: userId,
      sessionId: sessionId
    )
    print("Recieved challnge: \(challenge.count) bytes")

    let attestation = try await DCAppAttestService.shared.attestKey(
      keyId,
      clientDataHash: Data(SHA256.hash(data: challenge))
    )

    let assertion = try await DCAppAttestService.shared.generateAssertion(
      keyId,
      clientDataHash: Data(SHA256.hash(data: body))
    )

    return Payload(
      userId: userId,
      sessionId: sessionId,
      challenge: challenge,
      keyId: keyId,
      attestation: attestation,
      assertion: assertion,
      body: body
    )
  }
}

struct Payload: Encodable {
  var userId: UUID
  var sessionId: UUID
  var challenge: Data
  var keyId: String
  var attestation: Data
  var assertion: Data
  var body: Data
}
