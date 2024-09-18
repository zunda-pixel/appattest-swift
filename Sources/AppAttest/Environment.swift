import Foundation

public enum Environment: String, CaseIterable, Sendable, Hashable {
  case production = "appattest"
  case development = "appattestdevelop"

  init?(bytes: Data) {
    if let id = Environment.allCases.first(where: { bytes == $0.bytes }) {
      self = id
    } else {
      return nil
    }
  }

  var bytes: Data {
    let data = Data(rawValue.utf8)
    switch self {
    case .production:
      return data + Data(repeatElement(0x00, count: 7))
    case .development:
      return data
    }
  }
}
