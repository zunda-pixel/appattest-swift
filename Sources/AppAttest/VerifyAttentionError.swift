public enum VerifyAttestationError: Error {
  case invalidFormat
  case invalidAaguid
  case invalidRelyingPartyID
  case invalidNonce
  case invalidPublicKey
  case invalidCounter
  case invalidKeyId
  case missingExtension
  case couldNotValidateCertificate
  case failedValidateCertificate
}
