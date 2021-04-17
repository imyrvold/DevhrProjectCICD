import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation

protocol APIRequest {
    var path: String { get }
    var httpMethod: AWSLambdaEvents.HTTPMethod { get }
    var queryStringParameters: [String: String]? { get }
    var multiValueQueryStringParameters: [String: [String]]? { get }
    var headers: AWSLambdaEvents.HTTPHeaders { get }
    var multiValueHeaders: HTTPMultiValueHeaders { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

struct MyHandler {
    
}

Lambda.run { (context: Lambda.Context, event: APIGateway.Request, callback: @escaping (Result<APIGateway.Response, Error>) -> Void) in
    guard
        let bodyData = event.body?.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any]
    else {
        callback(.success(APIGateway.Response(statusCode: .badRequest)))
        return
    }
    
    callback(.success(APIGateway.Response(statusCode: .ok, body: "fint")))
}

