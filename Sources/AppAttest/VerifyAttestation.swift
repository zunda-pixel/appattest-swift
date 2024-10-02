import Foundation
import X509
import CryptoKit
import PotentCBOR
import SwiftASN1

extension AppAttest {
  public func verifyAttestatin(
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
    
    guard attestation.authenticatorData.counter == 0 else {
      throw AppAttestError.invalidCounter
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
  
  static func verifyNonce(
    challenge: Data,
    credetialCertificate: X509.Certificate,
    authenticateData: Attestation.AuthenticatorData
  ) throws {
    let clientDataHash = Data(SHA256.hash(data: challenge))
    let nonceData: Data = Data(SHA256.hash(data: authenticateData.rawData + clientDataHash))
    let ext = credetialCertificate.extensions.first(where: { $0.oid == [1, 2, 840, 113635, 100, 8, 2]})!
    let der = try DER.parse(ext.value)
    let octet = try SingleOctetSequence(derEncoded: der)
    if Data(octet.octet.bytes) != nonceData {
      fatalError()
    }
  }
  
  // Complete
  func verifyRelyingParty(
    authenticatorData: Attestation.AuthenticatorData
  ) throws {
    let appId = Data(SHA256.hash(data: Data("\(self.teamId).\(self.bundleId)".utf8)))
    if authenticatorData.relyingPartyId != appId {
      throw AppAttestError.invalidRelyingPartyID
    }
  }
  
  // Complete
  static func verifyCredentialId(
    keyId: Data,
    authenticatorData: Attestation.AuthenticatorData
  ) throws {
    guard let keyId = String(decoding: keyId, as: UTF8.self).base64Decoded() else {
      throw AppAttestError.invalidKeyId
    }

    if keyId != authenticatorData.credentialId {
      throw AppAttestError.invalidKeyId
    }
  }
  
  // Complete
  static func verifyKeyId(
    keyId: Data,
    credetialCertificate: X509.Certificate
  ) throws {
    guard let publicKey = P256.Signing.PublicKey(credetialCertificate.publicKey) else {
      throw AppAttestError.invalidPublicKey
    }
    
    let hashedPublicKey = Data(SHA256.hash(data: publicKey.x963Representation))
    
    guard let keyId = String(decoding: keyId, as: UTF8.self).base64Decoded() else {
      throw AppAttestError.invalidKeyId
    }
    
    if keyId != hashedPublicKey {
      throw AppAttestError.invalidKeyId
    }
  }
  
  func verifyRelying() throws {
    
  }
  
  // Complete
  static func verifyCertificates(
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
    case .couldNotValidate(let failures):
      throw AppAttestError.couldNotValidateCertificate
    case .validCertificate(let certificates):
      if Set(certificates) != Set([appleAppAttestationRootCa, credetialCertificate, intermediateCertificateAuthority]) {
        throw AppAttestError.failedValidateCertificate
      }
    }
  }
}

// https://github.com/Tyler-Keith-Thompson/RandomSideProjects/blob/60eba19e25f0aeb790c23d814924e977be400fb8/AppleAttestationService/Sources/App/Models/ASN1/SingleOctetSequence.swift
struct SingleOctetSequence: DERParseable {
  let octet: ASN1OctetString
  
  init(derEncoded rootNode: ASN1Node) throws {
    octet = try DER.sequence(rootNode, identifier: rootNode.identifier) { nodes in
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
    var encoded = replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    
    // Swift requires padding, but other languages don't always
    while encoded.count % 4 != 0 {
      encoded += "="
    }
    
    return Data(base64Encoded: encoded, options: .ignoreUnknownCharacters)
  }
}

