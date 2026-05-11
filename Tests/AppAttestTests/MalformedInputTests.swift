import AppAttest
import Foundation
import Testing

@Test
func attestationAuthenticatorDataRejectsShortInput() throws {
  let encodedData = try JSONEncoder().encode(Data(repeating: 0, count: 54))

  #expect(throws: DecodingError.self) {
    _ = try JSONDecoder().decode(Attestation.AuthenticatorData.self, from: encodedData)
  }
}

@Test
func assertionAuthenticatorDataRejectsShortInput() throws {
  let encodedData = try JSONEncoder().encode(Data(repeating: 0, count: 36))

  #expect(throws: DecodingError.self) {
    _ = try JSONDecoder().decode(Assertion.AuthenticatorData.self, from: encodedData)
  }
}

@Test
func attestationStatementRejectsInvalidCertificateCount() throws {
  struct StatementData: Encodable {
    var x5c: [Data]
    var receipt: Data
  }

  let encodedData = try JSONEncoder().encode(StatementData(x5c: [], receipt: Data()))

  #expect(throws: DecodingError.self) {
    _ = try JSONDecoder().decode(Attestation.Statement.self, from: encodedData)
  }
}
