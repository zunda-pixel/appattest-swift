import CBOR
import Crypto
import Foundation
import Testing

@testable import AppAttest

/// The sample attestation object from Apple's attestation object validation guide, produced by
/// an iOS 27 device and therefore carrying the App Attest authenticator extensions.
///
/// https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
private let appleSampleAttestation = """
  o2NmbXRvYXBwbGUtYXBwYXR0ZXN0Z2F0dFN0bXSiY3g1Y4JZBCEwggQdMIIDo6ADAgECAgYBnbE/C04wCgYIKoZIzj\
  0EAwIwTzEjMCEGA1UEAwwaQXBwbGUgQXBwIEF0dGVzdGF0aW9uIENBIDExEzARBgNVBAoMCkFwcGxlIEluYy4xEzAR\
  BgNVBAgMCkNhbGlmb3JuaWEwHhcNMjYwNDIwMTgxMzEyWhcNMjYwNDIzMTgxMzEyWjCBkTFJMEcGA1UEAwxAY2UwND\
  k4ZjU4NDgzZmJiNGRhMGQ3YjJjNjNhNWE1MzhmNTUyZDRhZGNiOWE0ZmE5MTYxOTVjNDk2MTNlNjU1ZDEaMBgGA1UE\
  CwwRQUFBIENlcnRpZmljYXRpb24xEzARBgNVBAoMCkFwcGxlIEluYy4xEzARBgNVBAgMCkNhbGlmb3JuaWEwWTATBg\
  cqhkjOPQIBBggqhkjOPQMBBwNCAARDMlRKzzI9t3REPKrzOfVufpXHJPrCwUJZ82XiRFZQsrX7KFvPVJvLYFlEEudo\
  KiQn7q2p+1Lf7QsasX7Qn6m9o4ICJjCCAiIwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBPAwFAYDVR0lBA0wCw\
  YJKoZIhvdjZAQYMHoGCSqGSIb3Y2QIBQRtMGukAwIBCr+JMAMCAQC/iTEDAgEAv4kyAwIBAL+JMwMCAQC/iTQeBBwx\
  MjM0NTY3ODkwLmNvbS5leGFtcGxlLm15YXBwv4k2AwIBBL+JNwMCAQC/iTkDAgEAv4k6AwIBAL+JOwMCAQCqAwIBAD\
  CB4AYJKoZIhvdjZAgHBIHSMIHPv4p4BgQEMjcuML+IUAMCAQK/inkJBAcxLjAuMjE2v4p7CQQHMjRBMzI1Yr+KfAYE\
  BDI3LjC/in0GBAQyNy4wv4p+AwIBAL+KfwMCAQC/iwADAgEAv4sBAwIBAL+LAgMCAQC/iwMDAgEAv4sEAwIBAb+LBQ\
  MCAQC/iwoQBA4yNC4xLjMyNS4wLjIsML+LCxAEDjI0LjEuMzI1LjAuMiwwv4sMEAQOMjQuMS4zMjUuMC4yLDC/iAIK\
  BAhpcGhvbmVvc7+IBQoECEludGVybmFsMDMGCSqGSIb3Y2QIAgQmMCShIgQgh7fQbZOkKU5G8BHma2zEAPC6sgcpl2\
  xhlYC0KuYL/24wWAYJKoZIhvdjZAgGBEswSaNHBEUwQwwCMTEwPTAKDANva2ShAwEB/zAJDAJvYaEDAQH/MAsMBG9z\
  Z26hAwEB/zALDARvZGVsoQMBAf8wCgwDb2NroQMBAf8wCgYIKoZIzj0EAwIDaAAwZQIwIbzHaPbRKcm2sa4JvDWyTX\
  40yz9U2byxFxTho+HIM0HeYwF3HLyA3Nrqv3WDy/UdAjEApOoxL7zeQV0yhvasPe31+c1ZYuEDxEU6rDrheFcVMRZe\
  pvV10+hFxgIWVMSpQu09WQJHMIICQzCCAcigAwIBAgIQCbrF4bxAGtnUU5W8OBoIVDAKBggqhkjOPQQDAzBSMSYwJA\
  YDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwKQXBwbGUgSW5jLjETMBEGA1UECAwK\
  Q2FsaWZvcm5pYTAeFw0yMDAzMTgxODM5NTVaFw0zMDAzMTMwMDAwMDBaME8xIzAhBgNVBAMMGkFwcGxlIEFwcCBBdH\
  Rlc3RhdGlvbiBDQSAxMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMHYwEAYHKoZIzj0C\
  AQYFK4EEACIDYgAErls3oHdNebI1j0Dn0fImJvHCX+8XgC3qs4JqWYdP+NKtFSV4mqJmBBkSSLY8uWcGnpjTY71eNw\
  +/oI4ynoBzqYXndG6jWaL2bynbMq9FXiEWWNVnr54mfrJhTcIaZs6Zo2YwZDASBgNVHRMBAf8ECDAGAQH/AgEAMB8G\
  A1UdIwQYMBaAFKyREFMzvb5oQf+nDKnl+url5YqhMB0GA1UdDgQWBBQ+410cBBmpybQx+IR01uHhV3LjmzAOBgNVHQ\
  8BAf8EBAMCAQYwCgYIKoZIzj0EAwMDaQAwZgIxALu+iI1zjQUCz7z9Zm0JV1A1vNaHLD+EMEkmKe3R+RToeZkcmui1\
  rvjTqFQz97YNBgIxAKs47dDMge0ApFLDukT5k2NlU/7MKX8utN+fXr5aSsq2mVxLgg35BDhveAe7WJQ5t2dyZWNlaX\
  B0WQ+JMIAGCSqGSIb3DQEHAqCAMIACAQExDzANBglghkgBZQMEAgEFADCABgkqhkiG9w0BBwGggCSABIID6DGCBUEw\
  JAIBAgIBAQQcMTIzNDU2Nzg5MC5jb20uZXhhbXBsZS5teWFwcDCCBCsCAQMCAQEEggQhMIIEHTCCA6OgAwIBAgIGAZ\
  2xPwtOMAoGCCqGSM49BAMCME8xIzAhBgNVBAMMGkFwcGxlIEFwcCBBdHRlc3RhdGlvbiBDQSAxMRMwEQYDVQQKDApB\
  cHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMB4XDTI2MDQyMDE4MTMxMloXDTI2MDQyMzE4MTMxMlowgZExST\
  BHBgNVBAMMQGNlMDQ5OGY1ODQ4M2ZiYjRkYTBkN2IyYzYzYTVhNTM4ZjU1MmQ0YWRjYjlhNGZhOTE2MTk1YzQ5NjEz\
  ZTY1NWQxGjAYBgNVBAsMEUFBQSBDZXJ0aWZpY2F0aW9uMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYW\
  xpZm9ybmlhMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEQzJUSs8yPbd0RDyq8zn1bn6VxyT6wsFCWfNl4kRWULK1\
  +yhbz1Sby2BZRBLnaCokJ+6tqftS3+0LGrF+0J+pvaOCAiYwggIiMAwGA1UdEwEB/wQCMAAwDgYDVR0PAQH/BAQDAg\
  TwMBQGA1UdJQQNMAsGCSqGSIb3Y2QEGDB6BgkqhkiG92NkCAUEbTBrpAMCAQq/iTADAgEAv4kxAwIBAL+JMgMCAQC/\
  iTMDAgEAv4k0HgQcMTIzNDU2Nzg5MC5jb20uZXhhbXBsZS5teWFwcL+JNgMCAQS/iTcDAgEAv4k5AwIBAL+JOgMCAQ\
  C/iTsDAgEAqgMCAQAwgeAGCSqGSIb3Y2QIBwSB0jCBz7+KeAYEBDI3LjC/iFADAgECv4p5CQQHMS4wLjIxNr+KewkE\
  BzI0QTMyNWK/inwGBAQyNy4wv4p9BgQEMjcuML+KfgMCAQC/in8DAgEAv4sAAwIBAL+LAQMCAQC/iwIDAgEAv4sDAw\
  IBAL+LBAMCAQG/iwUDAgEAv4sKEAQOMjQuMS4zMjUuMC4yLDC/iwsQBA4yNC4xLjMyNS4wLjIsML+LDBAEDjI0LjEu\
  MzI1LjAuMiwwv4gCCgQIaXBob25lb3O/iAUKBAhJbnRlcm5hbDAzBgkqhkiG92NkCAIEJjAkoSIEIIe30G2TpClORv\
  AR5mtsxADwurIHKZdsYZWAtCrmC/9uMFgGCSqGSIb3Y2QIBgRLMEmjRwRFMEMMAjExMD0wCgwDb2tkoQMBAf8wCQwC\
  b2GhAwEB/zALDARvc2duoQMBAf8wCwwEb2RlbKEDAQH/MAoMA29ja6EDAQH/MAoGCCoEggFdhkjOPQQDAgNoADBlAj\
  AhvMdo9tEpybaxrgm8NbJNfjTLP1TZvLEXFOGj4cgzQd5jAXccvIDc2uq/dYPL9R0CMQCk6jEvvN5BXTKG9qw97fX5\
  zVli4QPERTqsOuF4VxUxFl6m9XXT6EXGAhZUxKlC7T0wIAIBBAIBAQQYZXhhbXBsZV9zZXJ2ZXJfY2hhbGxlbmdlMG\
  ACAQUCAQEEWHJia3RNcTg5bXZEcFJDSy84bGNQaGRMNGRXUXo5T1hJd0hHZGU1eFFmU3VJS3NOM09qT1dGOHUrdjBV\
  QTRxOHZqQ1JnRUVKVGxjOUJ3aUl6TlNOT0hRPT0wDgIBBgIBAQQGQVRURVNUMBICAQcCAQEECnByb2R1Y3Rpb24wIA\
  IBDAIBAQQYMjAyNi0wNC0yMVQxODoxMzoxMi4xNTNaMCACARUCAQEEGDIwMjYtMDctMjBUMTg6MTM6MTIuMTUzWgAA\
  AAAAAKCAMIIDrjCCA1SgAwIBAgIQZgI4gAAUJvddiw4VLF9uQzAKBggqhkjOPQQDAjB8MTAwLgYDVQQDDCdBcHBsZS\
  BBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0\
  aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzAeFw0yNjAxMjAyMDIxMDlaFw0yNzAyMTgxOD\
  U4MzlaMFoxNjA0BgNVBAMMLUFwcGxpY2F0aW9uIEF0dGVzdGF0aW9uIEZyYXVkIFJlY2VpcHQgU2lnbmluZzETMBEG\
  A1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAQ7GK7OxRmtilNRtE\
  BEtKMDmVe0zb1bhR/gGm/t4o3vsPqww2oCpB9EbgBtWA5WimeAiQfzSICRQ4sgzqpMndxWo4IB2DCCAdQwDAYDVR0T\
  AQH/BAIwADAfBgNVHSMEGDAWgBTZF/5LZ5A4S5L0287VV4AUC489yTBDBggrBgEFBQcBAQQ3MDUwMwYIKwYBBQUHMA\
  GGJ2h0dHA6Ly9vY3NwLmFwcGxlLmNvbS9vY3NwMDMtYWFpY2E1ZzEwMTCCARwGA1UdIASCARMwggEPMIIBCwYJKoZI\
  hvdjZAUBMIH9MIHDBggrBgEFBQcCAjCBtgyBs1JlbGlhbmNlIG9uIHRoaXMgY2VydGlmaWNhdGUgYnkgYW55IHBhcn\
  R5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbiBhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25k\
  aXRpb25zIG9mIHVzZSwgY2VydGlmaWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9uIHByYWN0aWNlIHN0YXRlbW\
  VudHMuMDUGCCsGAQUFBwIBFilodHRwOi8vd3d3LmFwcGxlLmNvbS9jZXJ0aWZpY2F0ZWF1dGhvcml0eTAdBgNVHQ4E\
  FgQUNFWJcHRgDiLSumfPpVtpwiPxyigwDgYDVR0PAQH/BAQDAgeAMA8GCSqGSIb3Y2QMDwQCBQAwCgYIKoZIzj0EAw\
  IDSAAwRQIgHGeXuYJF0dbccgS3mwI8r/h78u/4k33XIMReiuRlwusCIQD8yFmEzsmhLMKGqdSSdv3w0vYl3HX8fPiH\
  RWl75h6qtDCCAvkwggJ/oAMCAQICEFb7g9Qr/43DN5kjtVqubr0wCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbG\
  UgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBw\
  bGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTkwMzIyMTc1MzMzWhcNMzQwMzIyMDAwMDAwWjB8MTAwLgYDVQQDDCdBcH\
  BsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24g\
  QXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0\
  IABJLOY719hrGrKAo7HOGv+wSUgJGs9jHfpssoNW9ES+Eh5VfdEo2NuoJ8lb5J+r4zyq7NBBnxL0Ml+vS+s8uDfrqj\
  gfcwgfQwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBS7sN6hWDOImqSKmd6+veuv2sskqzBGBggrBgEFBQcBAQ\
  Q6MDgwNgYIKwYBBQUHMAGGKmh0dHA6Ly9vY3NwLmFwcGxlLmNvbS9vY3NwMDMtYXBwbGVyb290Y2FnMzA3BgNVHR8E\
  MDAuMCygKqAohiZodHRwOi8vY3JsLmFwcGxlLmNvbS9hcHBsZXJvb3RjYWczLmNybDAdBgNVHQ4EFgQU2Rf+S2eQOE\
  uS9NvO1VeAFAuPPckwDgYDVR0PAQH/BAQDAgEGMBAGCiqGSIb3Y2QGAgMEAgUAMAoGCCqGSM49BAMDA2gAMGUCMQCN\
  b6afoeDk7FtOc4qSfz14U5iP9NofWB7DdUr+OKhMKoMaGqoNpmRt4bmT6NFVTO0CMGc7LLTh6DcHd8vV7HaoGjpVOz\
  81asjF5pKw4WG+gElp5F8rqWzhEQKqzGHZOLdzSjCCAkMwggHJoAMCAQICCC3F/IjSxUuVMAoGCCqGSM49BAMDMGcx\
  GzAZBgNVBAMMEkFwcGxlIFJvb3QgQ0EgLSBHMzEmMCQGA1UECwwdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdH\
  kxEzARBgNVBAoMCkFwcGxlIEluYy4xCzAJBgNVBAYTAlVTMB4XDTE0MDQzMDE4MTkwNloXDTM5MDQzMDE4MTkwNlow\
  ZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcm\
  l0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAASY6S89QHKk\
  7ZMicoETHN0QlfHFo05x3BQW2Q7lpgUqd2R7X04407scRLV/9R+2MmJdyemEW08wTxFaAP1YWAyl9Q8sTQdHE3Xal5\
  eXbzFc7SudeyA72LlU2V6ZpDpRCjGjQjBAMB0GA1UdDgQWBBS7sN6hWDOImqSKmd6+veuv2sskqzAPBgNVHRMBAf8E\
  BTADAQH/MA4GA1UdDwEB/wQEAwIBBjAKBggqhkjOPQQDAwNoADBlAjEAg+nBxBZeGl00GNnt7/RsDgBGS7jfskYRxQ\
  /95nqMoaZrzsID1Jz1k8Z0uGrfqiMVAjBtZooQytQN1E/NjUM+tIpjpTNu423aF7dkH8hTJvmIYnQ5Cxdby1GoDOgY\
  A+eisigAADGB/TCB+gIBATCBkDB8MTAwLgYDVQQDDCdBcHBsZSBBcHBsaWNhdGlvbiBJbnRlZ3JhdGlvbiBDQSA1IC\
  0gRzExJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQsw\
  CQYDVQQGEwJVUwIQZgI4gAAUJvddiw4VLF9uQzANBglghkgBZQMEAgEFADAKBggqhkjOPQQDAgRHMEUCIFp+GIuJm5\
  vqJhLtDX40gGP90KJtLoPyzcLEuKHYMr9zAiEAgPafgwU16p2N6GvCC3Gj4BAb66R38+IP+Arn3QYbD9QAAAAAAABo\
  YXV0aERhdGFY4vRGbWj5HrbBBiDLfmPHKDJEaF7h1kZ7VBYOdTFyBX8DQAAAAABhcHBhdHRlc3QAAAAAAAAAACDOBJ\
  j1hIP7tNoNeyxjpaU49VLUrcuaT6kWGVxJYT5lXaUBAgMmIAEhWCBDMlRKzzI9t3REPKrzOfVufpXHJPrCwUJZ82Xi\
  RFZQsiJYILX7KFvPVJvLYFlEEudoKiQn7q2p+1Lf7QsasX7Qn6m9ondhcHBsZV9idW5kbGVfdmVyc2lvbl8wMWExeB\
  xhcHBsZV92YWxpZGF0aW9uX2NhdGVnb3J5XzAxRAEAAAA=
  """

/// The authenticator data of `appleSampleAttestation`, truncated to the bytes an OS older than
/// iOS 27 would have emitted, i.e. ending right after the credential public key.
private let preIOS27AttestationAuthenticatorData = """
  9EZtaPketsEGIMt+Y8coMkRoXuHWRntUFg51MXIFfwNAAAAAAGFwcGF0dGVzdAAAAAAAAAAAIM4EmPWEg/u02g17LGOl\
  pTj1UtSty5pPqRYZXElhPmVdpQECAyYgASFYIEMyVErPMj23dEQ8qvM59W5+lcck+sLBQlnzZeJEVlCyIlggtfsoW89U\
  m8tgWUQS52gqJCfuran7Ut/tCxqxftCfqb0=
  """

/// Attestation authenticator data captured from a device running iOS 27.0 (24A435).
///
/// Unlike Apple's documented sample, this build sets the `ED` flag, so the two fixtures
/// together cover both spellings.
private let ios27AttestationAuthenticatorData = """
  /3PQmDDZvKc1qrflz10gRrcebJM0xpafxRfN6ujU13/AAAAAAGFwcGF0dGVzdGRldmVsb3AAIEAAk2q9eHprerZmvx9Q\
  YVNe/TzH8t2tosuYiIs414s1pQECAyYgASFYIESVZHRrpydBHQg0wy/OjBC3Q2tSVZCfSQ3q3wrTI2kzIlggwd0u/mQp\
  FQPijjFgX59bwG1WeRsULAb0CGuE6EgKtgKid2FwcGxlX2J1bmRsZV92ZXJzaW9uXzAxYTF4HGFwcGxlX3ZhbGlkYXRp\
  b25fY2F0ZWdvcnlfMDFEAwAAAA==
  """

/// Assertion authenticator data from the same iOS 27.0 capture.
private let ios27AssertionAuthenticatorData = """
  /3PQmDDZvKc1qrflz10gRrcebJM0xpafxRfN6ujU13/AAAAAAaJ3YXBwbGVfYnVuZGxlX3ZlcnNpb25fMDFhMXgcYXBw\
  bGVfdmFsaWRhdGlvbl9jYXRlZ29yeV8wMUQDAAAA
  """

/// Minimal assertion authenticator data with no trailing bytes, hand built from the relying
/// party ID of Apple's sample: 32 byte RP ID hash, clear flags, counter 2.
private let assertionAuthenticatorDataWithoutExtensions =
  "9EZtaPketsEGIMt+Y8coMkRoXuHWRntUFg51MXIFfwMAAAAAAg=="

private func decodeAuthenticatorData<T: Decodable>(_ type: T.Type, base64: String) throws -> T {
  // `AuthenticatorData` decodes from a single value, so a JSON encoded `Data` round-trips it
  // without having to build a whole attestation or assertion object.
  let encodedData = try JSONEncoder().encode(Data(base64Encoded: base64)!)
  return try JSONDecoder().decode(type, from: encodedData)
}

@Test
func attestationExposesIOS27Extensions() throws {
  let attestation = try CBORDecoder().decode(
    Attestation.self,
    from: [UInt8](Data(base64Encoded: appleSampleAttestation)!)
  )

  let extensions = try #require(attestation.authenticatorData.extensions)
  #expect(extensions.validationCategory == .platform)
  #expect(extensions.bundleVersion == "1")
}

/// The extensions must stay inside `rawData`, because the nonce Apple puts in the credential
/// certificate is computed over the whole authenticator data.
@Test
func attestationRawDataKeepsTheExtensionBytes() throws {
  let attestation = try CBORDecoder().decode(
    Attestation.self,
    from: [UInt8](Data(base64Encoded: appleSampleAttestation)!)
  )

  let rawData = attestation.authenticatorData.rawData
  #expect(rawData.count == 226)

  // Apple's guide appends the challenge itself rather than its hash in this sample.
  let clientDataHash = Data("example_server_challenge".utf8)
  let nonce = Data(SHA256.hash(data: rawData + clientDataHash))
  #expect(nonce.base64EncodedString() == "h7fQbZOkKU5G8BHma2zEAPC6sgcpl2xhlYC0KuYL/24=")
}

@Test
func attestationWithoutExtensionsHasNoExtensions() throws {
  let authenticatorData = try decodeAuthenticatorData(
    Attestation.AuthenticatorData.self,
    base64: preIOS27AttestationAuthenticatorData
  )

  #expect(authenticatorData.extensions == nil)
}

/// The `ED` flag is set in shipping iOS 27.0 builds but clear in Apple's documented sample, so
/// the extensions have to be found without consulting it.
@Test
func attestationFromADeviceThatSetsTheExtensionDataFlagExposesExtensions() throws {
  let authenticatorData = try decodeAuthenticatorData(
    Attestation.AuthenticatorData.self,
    base64: ios27AttestationAuthenticatorData
  )

  #expect(authenticatorData.environment == .development)
  let extensions = try #require(authenticatorData.extensions)
  #expect(extensions.validationCategory == .development)
  #expect(extensions.bundleVersion == "1")
}

@Test
func assertionExposesIOS27Extensions() throws {
  let authenticatorData = try decodeAuthenticatorData(
    Assertion.AuthenticatorData.self,
    base64: ios27AssertionAuthenticatorData
  )

  #expect(authenticatorData.counter == 1)
  let extensions = try #require(authenticatorData.extensions)
  #expect(extensions.validationCategory == .development)
  #expect(extensions.bundleVersion == "1")
}

@Test
func assertionWithoutExtensionsHasNoExtensions() throws {
  let authenticatorData = try decodeAuthenticatorData(
    Assertion.AuthenticatorData.self,
    base64: assertionAuthenticatorDataWithoutExtensions
  )

  #expect(authenticatorData.extensions == nil)
}

@Test
func validationCategoryDecodesAppleLittleEndianEncoding() throws {
  #expect(ValidationCategory(cbor: .byteString([0x03, 0x00, 0x00, 0x00])) == .development)
  // Apple documents the value as a `UInt32`, so a plain integer is accepted too.
  #expect(ValidationCategory(cbor: .unsignedInt(2)) == .testFlight)
  #expect(ValidationCategory(cbor: .byteString([0x00, 0x00, 0x00])) == nil)
  #expect(ValidationCategory(cbor: .textString("4")) == nil)
}

/// A renamed key must not read as "no extensions", or a server cannot tell a future OS apart
/// from one that predates the extensions entirely.
@Test
func unrecognisedExtensionMapIsReportedWithNoValues() throws {
  // A CBOR map that carries none of the App Attest keys: {"other": 1}
  let trailingData = Data([0xA1, 0x65]) + Data("other".utf8) + Data([0x01])

  let decoded = try decodeAuthenticatorData(
    Assertion.AuthenticatorData.self,
    base64: (Data(base64Encoded: assertionAuthenticatorDataWithoutExtensions)! + trailingData)
      .base64EncodedString()
  )

  let extensions = try #require(decoded.extensions)
  #expect(extensions.validationCategory == nil)
  #expect(extensions.bundleVersion == nil)
}

@Test
func trailingDataThatIsNotAMapIsNotReportedAsExtensions() throws {
  // A CBOR text string rather than a map.
  let trailingData = Data([0x65]) + Data("other".utf8)

  let decoded = try decodeAuthenticatorData(
    Assertion.AuthenticatorData.self,
    base64: (Data(base64Encoded: assertionAuthenticatorDataWithoutExtensions)! + trailingData)
      .base64EncodedString()
  )

  #expect(decoded.extensions == nil)
}

/// iOS 27.0 sets `AT` on assertions even though they carry no attested credential data, so the
/// extension map has to be located by offset rather than by the flags byte.
@Test
func assertionSetsTheAttestedCredentialDataFlagWithoutAttestedCredentialData() throws {
  let authenticatorData = try decodeAuthenticatorData(
    Assertion.AuthenticatorData.self,
    base64: ios27AssertionAuthenticatorData
  )

  let rawData = authenticatorData.rawData
  let flags = rawData[rawData.startIndex + 32]
  #expect(flags & 0x40 != 0)
  #expect(flags & 0x80 != 0)
  // 32 byte RP ID hash + 1 flags + 4 counter + 62 extension map, with nothing in between.
  #expect(rawData.count == 99)
}
