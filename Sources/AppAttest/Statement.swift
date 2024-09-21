import Foundation
import SwiftASN1
import X509

public struct Statement: Decodable, Sendable, Hashable {
  public var certificates: [X509.Certificate]
  public var receipt: ASN1Node

  private enum CodingKeys: CodingKey {
    case x5c
    case receipt
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let x5cs = try container.decode([Data].self, forKey: .x5c)
    self.certificates = try x5cs.map {
      try X509.Certificate(derEncoded: Array($0))
    }
    let receipt = try container.decode(Data.self, forKey: .receipt)
    self.receipt = try BER.parse(Array(receipt))
  }
}
