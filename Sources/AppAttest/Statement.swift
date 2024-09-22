import Foundation
import SwiftASN1
import X509

public struct Statement: Decodable, Sendable, Hashable {
  /// credCer
  public var credetialCertificate: X509.Certificate
  /// intermediateCa(caCert)
  public var intermediateCertificateAuthority: X509.Certificate
  public var receipt: ASN1Node

  private enum CodingKeys: CodingKey {
    case x5c
    case receipt
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let x5cs = try container.decode([Data].self, forKey: .x5c)
    let certificates = try x5cs.map {
      try X509.Certificate(derEncoded: Array($0))
    }
    if let credetialCertificate = certificates.first {
      self.credetialCertificate = credetialCertificate
    } else {
      throw AppAttestError.missingCredetialCertificate
    }

    if let intermediateCertificateAuthority = certificates.last {
      self.intermediateCertificateAuthority = intermediateCertificateAuthority
    } else {
      throw AppAttestError.missingIntermediateCertificateAuthority
    }
    
    let receipt = try container.decode(Data.self, forKey: .receipt)
    let receipt1 = try BER.parse(Array(receipt))

    self.receipt = receipt1
  }
}
