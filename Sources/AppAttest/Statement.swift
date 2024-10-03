import Foundation
import SwiftASN1
import X509

extension Attestation {
  public struct Statement: Decodable, Sendable, Hashable {
    /// credCer
    public var credetialCertificate: X509.Certificate
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
      assert(x5cs.count == 2)

      let certificates = try x5cs.map {
        try X509.Certificate(derEncoded: Array($0))
      }

      self.credetialCertificate = certificates.first!
      self.intermediateCertificateAuthority = certificates.last!

      self.receipt = try container.decode(Data.self, forKey: .receipt)
    }
  }
}
