import Foundation
import X509
import CryptoKit
import PotentCBOR

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

    await try Self.verifyCertificates(
      credetialCertificate: attestation.statement.credetialCertificate,
      intermediateCertificateAuthority: attestation.statement.intermediateCertificateAuthority
    )
    
    try Self.verifyNonce(
      credetialCertificate: attestation.statement.credetialCertificate,
      authenticateData: attestation.authenticatorData.rawData,
      challenge: challenge
    )
    
    return attestation
  }
  
  static func verifyNonce(
    credetialCertificate: X509.Certificate,
    authenticateData: Data,
    challenge: Data
  ) throws {
    let clientDataHash = Data(SHA256.hash(data: challenge))
    let nonceData: Data = authenticateData + clientDataHash
    let oid = credetialCertificate.extensions[oid: .init(arrayLiteral: 1, 2, 840, 113635, 100, 8, 2)]!
    print(Array(nonceData))
    print(oid.value)
    //BER.parse(<#T##[UInt8]#>)
  }
  
  func verifyKeyId(keyId: Data) throws {
    
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
