import Foundation
import SwiftASN1
import X509

extension Attestation {
  public struct Statement: Decodable, Sendable, Hashable {
    /// credCer
    public var credentialCertificate: X509.Certificate
    /// intermediateCa(caCert)
    public var intermediateCertificateAuthority: X509.Certificate
    public var receipt: Data

    private enum CodingKeys: CodingKey {
      case x5c
      case receipt
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let x5cs = try container.decode([Data].self, forKey: .x5c)
      guard x5cs.count == 2 else {
        throw DecodingError.dataCorruptedError(
          forKey: .x5c,
          in: container,
          debugDescription:
            "Attestation statement must contain credential and intermediate certificates."
        )
      }

      let certificates = try x5cs.map {
        try X509.Certificate(derEncoded: Array($0))
      }

      self.credentialCertificate = certificates[0]
      self.intermediateCertificateAuthority = certificates[1]

      self.receipt = try container.decode(Data.self, forKey: .receipt)
    }
  }
}
