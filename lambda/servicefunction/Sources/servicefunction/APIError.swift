import Foundation

enum APIError: Error {
    case decodingError
    case requestError
    case getLabelsError
    case deleteError
}
