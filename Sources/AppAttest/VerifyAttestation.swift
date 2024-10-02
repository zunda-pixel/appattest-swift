import Crypto
import Foundation
import PotentCBOR
import SwiftASN1
import X509

extension AppAttest {
  public func verifyAttestation(
    challenge: Data,
    keyId: Data,
    attestation: Data,
    environment: Environment
  ) async throws -> Attestation {
    let attestation = try CBORDecoder.default.decode(Attestation.self, from: attestation)

    guard attestation.format == "apple-appattest" else {
      throw VerifyAttentionError.invalidFormat
    }
    guard attestation.authenticatorData.environment == environment else {
      throw VerifyAttentionError.invalidAaguid
    }

    guard attestation.authenticatorData.counter == 0 else {
      throw VerifyAttentionError.invalidCounter
    }

    try await Self.verifyCertificates(
      credetialCertificate: attestation.statement.credetialCertificate,
      intermediateCertificateAuthority: attestation.statement.intermediateCertificateAuthority
    )

    try Self.verifyKeyId(
      keyId: keyId,
      credetialCertificate: attestation.statement.credetialCertificate
    )

    try self.verifyRelyingParty(
      authenticatorData: attestation.authenticatorData
    )

    try Self.verifyCredentialId(
      keyId: keyId,
      authenticatorData: attestation.authenticatorData
    )

    try Self.verifyNonce(
      challenge: challenge,
      credetialCertificate: attestation.statement.credetialCertificate,
      authenticateData: attestation.authenticatorData
    )

    return attestation
  }

  static private func verifyNonce(
    challenge: Data,
    credetialCertificate: X509.Certificate,
    authenticateData: Attestation.AuthenticatorData
  ) throws {
    let clientDataHash = Data(SHA256.hash(data: challenge))
    let nonceData = Data(SHA256.hash(data: authenticateData.rawData + clientDataHash))
    let ext = credetialCertificate.extensions.first { $0.oid == [1, 2, 840, 113635, 100, 8, 2] }
    guard let ext else {
      throw VerifyAttentionError.missingExtension
    }
    let der = try DER.parse(ext.value)
    let octet = try SingleOctetSequence(derEncoded: der.encodedBytes)
    if Data(octet.octet.bytes) != nonceData {
      throw VerifyAttentionError.invalidNonce
    }
  }

  // Complete
  private func verifyRelyingParty(
    authenticatorData: Attestation.AuthenticatorData
  ) throws {
    let appId = Data(SHA256.hash(data: Data("\(self.teamId).\(self.bundleId)".utf8)))
    if authenticatorData.relyingPartyId != appId {
      throw VerifyAttentionError.invalidRelyingPartyID
    }
  }

  // Complete
  static private func verifyCredentialId(
    keyId: Data,
    authenticatorData: Attestation.AuthenticatorData
  ) throws {
    guard let keyId = String(decoding: keyId, as: UTF8.self).base64Decoded() else {
      throw VerifyAttentionError.invalidKeyId
    }

    if keyId != authenticatorData.credentialId {
      throw VerifyAttentionError.invalidKeyId
    }
  }

  // Complete
  static private func verifyKeyId(
    keyId: Data,
    credetialCertificate: X509.Certificate
  ) throws {
    guard let publicKey = P256.Signing.PublicKey(credetialCertificate.publicKey) else {
      throw VerifyAttentionError.invalidPublicKey
    }

    let hashedPublicKey = Data(SHA256.hash(data: publicKey.x963Representation))

    guard let keyId = String(decoding: keyId, as: UTF8.self).base64Decoded() else {
      throw VerifyAttentionError.invalidKeyId
    }

    if keyId != hashedPublicKey {
      throw VerifyAttentionError.invalidKeyId
    }
  }

  // Complete
  static private func verifyCertificates(
    credetialCertificate: Certificate,
    intermediateCertificateAuthority: Certificate
  ) async throws {
    let appleAppAttestationRootCa: X509.Certificate

    do {
      let path = Bundle.module.url(
        forResource: "Apple_App_Attestation_Root_CA",
        withExtension: "pem"
      )!
      let certificateData = try Data(contentsOf: path)
      let certificateDataString = String(decoding: certificateData, as: UTF8.self)
      appleAppAttestationRootCa = try X509.Certificate(
        pemEncoded: certificateDataString
      )
    }

    var verifier = X509.Verifier(rootCertificates: .init([appleAppAttestationRootCa])) {
      RFC5280Policy(validationTime: .now)
    }

    let result = await verifier.validate(
      leafCertificate: credetialCertificate,
      intermediates: .init([intermediateCertificateAuthority])
    )

    switch result {
    case .couldNotValidate(_):
      throw VerifyAttentionError.couldNotValidateCertificate
    case .validCertificate(let certificates):
      let allCertificates = [
        appleAppAttestationRootCa,
        credetialCertificate,
        intermediateCertificateAuthority
      ]
      if Set(certificates) != Set(allCertificates) {
        throw VerifyAttentionError.failedValidateCertificate
      }
    }
  }
}

// https://github.com/Tyler-Keith-Thompson/RandomSideProjects/blob/60eba19e25f0aeb790c23d814924e977be400fb8/AppleAttestationService/Sources/App/Models/ASN1/SingleOctetSequence.swift
struct SingleOctetSequence: DERParseable {
  let octet: ASN1OctetString

  init(derEncoded rootNode: ASN1Node) throws {
    self.octet = try DER.sequence(rootNode, identifier: rootNode.identifier) { nodes in
      guard let node = nodes.next() else {
        throw ASN1Error.invalidASN1Object(reason: "Empty sequence! Expected single octet")
      }
      return try DER.sequence(node, identifier: node.identifier) {
        try ASN1OctetString(derEncoded: &$0)
      }
    }
  }
}

extension String {
  func base64Decoded() -> Data? {
    var encoded =
      self
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    // Swift requires padding, but other languages don't always
    while encoded.count % 4 != 0 {
      encoded += "="
    }

    return Data(
      base64Encoded: encoded,
      options: .ignoreUnknownCharacters
    )
  }
}
