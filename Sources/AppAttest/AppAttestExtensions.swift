import CBOR
import Foundation

/// The App Attest authenticator extensions that iOS 27 and later append to authenticator data.
///
/// The WebAuthn `ED` (extension data included) flag is not a reliable signal here: iOS 27.0
/// sets it, while the sample in Apple's validation guide carries the extensions with it clear.
/// The extensions are therefore detected by the presence of trailing CBOR rather than by the
/// flag.
///
/// Nothing here is ever a hard requirement. The whole value is `nil` only when the
/// authenticator data carries no extension map at all, and an individual key that is missing
/// or encoded in an unexpected way is reported as `nil` rather than failing the verification,
/// which relies on `rawData` instead. A map whose keys this version does not recognise is
/// therefore reported with every property `nil`, which says "extensions present, nothing
/// readable" instead of masquerading as a device that predates them.
///
/// https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
public struct AppAttestExtensions: Sendable, Hashable {
  /// The `apple_validation_category_01` extension: how the OS validated the running app.
  public var validationCategory: ValidationCategory?
  /// The `apple_bundle_version_01` extension: the bundle version of the running app.
  public var bundleVersion: String?

  public init(
    validationCategory: ValidationCategory?,
    bundleVersion: String?
  ) {
    self.validationCategory = validationCategory
    self.bundleVersion = bundleVersion
  }
}

extension AppAttestExtensions {
  static let validationCategoryKey = "apple_validation_category_01"
  static let bundleVersionKey = "apple_bundle_version_01"

  init?(cbor: CBOR) {
    // The authenticator extension model puts a map here, so any map is one, recognised keys
    // or not. Requiring a known key instead would report a future renaming as no extensions.
    guard case .map = cbor else { return nil }

    self.init(
      validationCategory: cbor[Self.validationCategoryKey]
        .flatMap(ValidationCategory.init(cbor:)),
      bundleVersion: cbor[Self.bundleVersionKey]?.string
    )
  }

  /// Reads the extension map out of the bytes that follow the fixed size authenticator data
  /// fields.
  ///
  /// - Parameters:
  ///   - bytes: The remainder of the authenticator data.
  ///   - skippedItems: The number of CBOR items that precede the extension map. Attestation
  ///     authenticator data holds the credential public key there; assertion authenticator
  ///     data holds nothing.
  init?(trailingBytes bytes: Data, skippedItems: Int) {
    var remaining = [UInt8](bytes)[...]

    for _ in 0..<skippedItems {
      guard
        let (_, consumedBytes) = try? CBOR.decodeFirst(remaining),
        consumedBytes > 0
      else { return nil }
      remaining = remaining.dropFirst(consumedBytes)
    }

    guard
      !remaining.isEmpty,
      let cbor = try? CBOR.decodeFirst(remaining).value
    else { return nil }

    self.init(cbor: cbor)
  }
}
