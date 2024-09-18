public enum AppAttestError: Error {
  case invalidFormat
  case invalidAaguid
  case invalidRelyingPartyID
  case invalidCredentialId
  case missingCertificate
  case missingValidCertificate
  case invalidNonce
  case invalidPublicKey
  case invalidCounter
  case invalidKeyId
  case missingExtension
}
