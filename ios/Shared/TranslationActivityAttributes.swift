import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct TranslationActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var status: String
    var transcript: String
    var translation: String
  }

  var sourceLanguage: String
  var targetLanguage: String
}
