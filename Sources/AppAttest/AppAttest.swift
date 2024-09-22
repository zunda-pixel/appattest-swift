import CryptoKit
import Foundation
import PotentCBOR
import X509

public struct AppAttest {
  public var teamId: String
  public var bundleId: String

  public init(
    teamId: String,
    bundleId: String
  ) {
    self.teamId = teamId
    self.bundleId = bundleId
  }
  
  public func verify(
    challenge: Data,
    keyId: Data,
    attestation: Data,
    environment: Environment
  ) async throws -> Attestation {
    let attestation = try CBORDecoder.default.decode(Attestation.self, from: attestation)

    guard attestation.format == "apple-appattest" else {
      throw AppAttestError.invalidFormat
    }
    guard attestation.authenticatorData.environment == environment else {
      throw AppAttestError.invalidAaguid
    }
    let relyingPartyId = Data(SHA256.hash(data: Data("\(teamId).\(bundleId)".utf8)))
    guard attestation.authenticatorData.relyingPartyId == relyingPartyId else {
      throw AppAttestError.invalidRelyingPartyID
    }

    guard attestation.authenticatorData.credentialId == keyId else {
      throw AppAttestError.invalidKeyId
    }
    
    guard attestation.authenticatorData.counter == 0 else {
      throw AppAttestError.invalidCounter
    }
    
    try Self.verifyPublicKey(
      keyId: keyId,
      certificate: attestation.statement.credetialCertificate
    )
    
    let nonce = Self.nonce(
      challenge: challenge,
      authenticatorData: attestation.authenticatorData.rawData
    )
    
//    guard Array(nonce) == Array(Data()) else {
//      throw AppAttestError.invalidNonce
//    }
    
    return attestation
  }
  
  static func verifyPublicKey(
    keyId: Data,
    certificate: Certificate
  ) throws {
    let publicKey = certificate.publicKey
    let hash = SHA256.hash(data: publicKey.subjectPublicKeyInfoBytes)
    if hash == keyId {
      return
    } else {
      throw AppAttestError.invalidPublicKey
    }
  }

  static func nonce(
    challenge: Data,
    authenticatorData: Data
  ) -> SHA256.Digest {
    let hashedChallenge = Data(SHA256.hash(data: challenge))
    return SHA256.hash(data: authenticatorData + hashedChallenge)
  }
}
