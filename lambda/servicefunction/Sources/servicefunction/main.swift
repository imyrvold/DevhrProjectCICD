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

Lambda.run { (context: Lambda.Context, input: Input, callback: @escaping (Result<APIGateway.Response, Error>) -> Void) in
    context.logger.info("Lambda.run input: \(input)")
    
//    let awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
    let handler = ServiceHandler(context: context)
    handler.handle(context: context, input: input)


    callback(.success(APIGateway.Response(statusCode: .ok, body: "fint")))
}

//Lambda.run { ServiceHandler(context: $0) }
