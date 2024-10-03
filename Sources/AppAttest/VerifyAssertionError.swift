public enum VerifyAssertionError: Error {
  case invalidNonce
  case invalidPublicKey
  case invalidRelyingPartyID
  case invalidCounter
}
