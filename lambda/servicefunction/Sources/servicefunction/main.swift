import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import NIO

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

/*Lambda.run { (context: Lambda.Context, input: Input, callback: @escaping (Result<APIGateway.Response, Error>) -> Void) in
    context.logger.info("Lambda.run input: \(input)")
    
//    let awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
    let handler = ServiceHandler(context: context)
    _ = handler.handle(context: context, input: input)
        .map { result in
            context.logger.info("Lambda.run body: \(result.body), statusCode: \(result.statusCode)")
            callback(.success(APIGateway.Response(statusCode: result.statusCode, body: result.body)))
        }
        


}*/

Lambda.run { ServiceHandler(context: $0) }
