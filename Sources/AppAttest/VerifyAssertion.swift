import Crypto
import Foundation
import PotentCBOR
import X509

extension AppAttest {
  public func verifyAsssertion(
    assertion: Data,
    payload: Data,
    certificate: X509.Certificate,  // credentialCertificate from db attestation
    counter: UInt32  // counter from db attestation
  ) throws {
    let assertion = try CBORDecoder.default.decode(Assertion.self, from: assertion)

    if assertion.authenticatorData.counter <= counter {
      throw VerifyAssertionError.invalidCounter
    }

    try verifyRelyingPartyId(
      relyingPartyId: assertion.authenticatorData.relyingPartyId
    )

    try Self.verifyNonce(
      assetion: assertion,
      payload: payload,
      certificate: certificate
    )
  }

  static private func verifyNonce(
    assetion: Assertion,  // Client
    payload: Data,  // Client
    certificate: X509.Certificate  // Server
  ) throws {
    let clientDataHash = Data(SHA256.hash(data: payload))
    let nonceData: Data = assetion.authenticatorData.rawData + clientDataHash
    let nonce = Data(SHA256.hash(data: nonceData))
    let signature = try P256.Signing.ECDSASignature(derRepresentation: assetion.signature)
    guard let publicKey = P256.Signing.PublicKey(certificate.publicKey) else {
      throw VerifyAssertionError.invalidPublicKey
    }
    if publicKey.isValidSignature(signature, for: nonce) == false {
      throw VerifyAssertionError.invalidNonce
    }
  }

  private func verifyRelyingPartyId(relyingPartyId: Data) throws {
    let appIdHash = Data(SHA256.hash(data: Data("\(self.teamId).\(self.bundleId)".utf8)))
    if relyingPartyId != appIdHash {
      throw VerifyAssertionError.invalidRelyingPartyID
    }
  }
}
