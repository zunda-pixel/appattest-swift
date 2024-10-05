import DeviceCheck
import Valet
import HTTPTypes
import HTTPTypesFoundation
import CryptoKit

let baseUrl: URL = URL(string: <#BASE_URL#>)!

enum Client {
  static func execute(
    body: Data
  ) async throws -> (Data, HTTPResponse) {
    let url = baseUrl.appending(path: "createUser")
    let request = HTTPRequest(
      method: .post,
      url: url
    )
    
    let payload = try await prepareData(body: body)
    
    let payloadData = try JSONEncoder().encode(payload)
    
    return try await URLSession.shared.upload(
      for: request,
      from: payloadData
    )
  }

  static func getChallenge() async throws -> Data {
    let url = baseUrl.appending(path: "challenge")
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
  
  static private func keyId() async throws -> String {
    let valet = Valet.valet(
      with: .init(nonEmpty: "AppAttestExample")!,
      accessibility: .whenUnlocked
    )
    
    if try valet.containsObject(forKey: "keyId") {
      return try valet.string(forKey: "keyId")
    } else {
      let keyId = try await DCAppAttestService.shared.generateKey()
      try valet.setString(keyId, forKey: "keyId")
      return keyId
    }
  }
  
  static private func prepareData(body: Data) async throws -> Payload {
    let keyId = try await keyId()
    let challenge = try await getChallenge()
    
    let attestation = try await DCAppAttestService.shared.attestKey(
      keyId,
      clientDataHash: Data(SHA256.hash(data: challenge))
    )
        
    let assertion = try await DCAppAttestService.shared.generateAssertion(
      keyId,
      clientDataHash: Data(SHA256.hash(data: body))
    )
    
    return Payload(
      challenge: challenge,
      keyId: keyId,
      attestaion: attestation,
      assertion: assertion,
      body: body
    )
  }
}

struct Payload: Encodable {
  let challenge: Data
  let keyId: String
  let attestaion: Data
  let assertion: Data
  let body: Data
}
