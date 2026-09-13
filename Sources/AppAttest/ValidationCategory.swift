import CBOR

/// The value of the `apple_validation_category_01` authenticator extension.
///
/// It reports how the operating system validated the executable that produced the
/// attestation or assertion, which lets a server tell an App Store build apart from a
/// TestFlight, development or enterprise one.
///
/// The category is modelled as a raw value rather than a closed enum so that a value a
/// future OS introduces still round-trips instead of being dropped.
///
/// https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
public struct ValidationCategory: RawRepresentable, Sendable, Hashable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  /// No valid category. (`CS_VALIDATION_CATEGORY_INVALID`)
  public static let invalid = ValidationCategory(rawValue: 0)
  /// An executable distributed with the operating system. (`CS_VALIDATION_CATEGORY_PLATFORM`)
  public static let platform = ValidationCategory(rawValue: 1)
  /// An app distributed through TestFlight. (`CS_VALIDATION_CATEGORY_TESTFLIGHT`)
  public static let testFlight = ValidationCategory(rawValue: 2)
  /// An app signed with a development certificate. (`CS_VALIDATION_CATEGORY_DEVELOPMENT`)
  public static let development = ValidationCategory(rawValue: 3)
  /// An app distributed through the App Store. (`CS_VALIDATION_CATEGORY_APP_STORE`)
  public static let appStore = ValidationCategory(rawValue: 4)
  /// An app distributed through the Apple Developer Enterprise Program. (`CS_VALIDATION_CATEGORY_ENTERPRISE`)
  public static let enterprise = ValidationCategory(rawValue: 5)
  /// An app signed with a Developer ID certificate. (`CS_VALIDATION_CATEGORY_DEVELOPER_ID`)
  public static let developerID = ValidationCategory(rawValue: 6)
  /// An app signed locally on the device. (`CS_VALIDATION_CATEGORY_LOCAL_SIGNING`)
  public static let localSigning = ValidationCategory(rawValue: 7)
  /// A Rosetta translated executable. (`CS_VALIDATION_CATEGORY_ROSETTA`)
  public static let rosetta = ValidationCategory(rawValue: 8)
  /// An out-of-process JIT executable. (`CS_VALIDATION_CATEGORY_OOPJIT`)
  public static let oopJIT = ValidationCategory(rawValue: 9)
  /// An executable without a validation category. (`CS_VALIDATION_CATEGORY_NONE`)
  public static let noValidation = ValidationCategory(rawValue: 10)
}

extension ValidationCategory {
  /// Apple encodes the category as a four byte little endian `UInt32` byte string, but
  /// documents it as a `UInt32`, so both encodings are accepted.
  init?(cbor: CBOR) {
    if let bytes = cbor.bytes {
      guard bytes.count == 4 else { return nil }
      let rawValue = bytes.reversed().reduce(UInt32(0)) { value, byte in
        value << 8 | UInt32(byte)
      }
      self.init(rawValue: rawValue)
    } else if let value = cbor.uint64, let rawValue = UInt32(exactly: value) {
      self.init(rawValue: rawValue)
    } else {
      return nil
    }
  }
}
