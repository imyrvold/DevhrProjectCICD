//
//  File.swift
//  
//
//  Created by Ivan C Myrvold on 11/04/2021.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import SotoDynamoDB
import SotoS3
import NIO
import Foundation

struct Input: Codable {
    enum Action: String, Codable {
        case getLabels, deleteImage
    }

    let action: Action
    let key: String
}

struct LabelsOutput: Codable {
    let labels: [String]
}

struct DeleteOutput: Codable {
    let result: String
}

struct ServiceHandler: EventLoopLambdaHandler {
    typealias In = APIGateway.Request
    typealias Out = APIGateway.Response
    
    let awsClient: AWSClient

    init(context: Lambda.InitializationContext) {
        self.awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
    }

    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        let promise = context.eventLoop.makePromise(of: Void.self)
        awsClient.shutdown { error in
            if let error = error {
                promise.fail(error)
            } else {
                promise.succeed(())
            }
        }
        
        return context.eventLoop.makeSucceededFuture(())
    }
    
    func handle(context: Lambda.Context, event: APIGateway.Request) -> EventLoopFuture<Out> {
        context.logger.info("handle 1")
        guard let input: Input = try? event.bodyObject() else {
            return context.eventLoop.makeSucceededFuture(APIGateway.Response(with: APIError.requestError, statusCode: .badRequest))
        }
        context.logger.info("handle 2")

        switch input.action {
        case .getLabels:
            return getLabels(with: input.key, context: context)
                .flatMap { result in
                    switch result {
                    case .success(let imageLabel):
                        let names = imageLabel.labels.map { $0.name }
                        
                        let output = LabelsOutput(labels: names)
                        let apigatewayOutput = APIGateway.Response(with: output, statusCode: .ok)
                        
                        return context.eventLoop.makeSucceededFuture(apigatewayOutput)
                    case .failure(let error):
                        let apigatewayOutput = APIGateway.Response(with: error, statusCode: .notFound)
                        
                        return context.eventLoop.makeSucceededFuture(apigatewayOutput)
                    }
                }
        case .deleteImage:
            return deleteImage(with: input.key, context: context)
                .flatMap { result in
                    switch result {
                    case .success(let text):
                        let apigatewayOutput = APIGateway.Response(with: text, statusCode: .ok)
                        
                        return context.eventLoop.makeSucceededFuture(apigatewayOutput)
                    case .failure(let error):
                        let apigatewayOutput = APIGateway.Response(with: error, statusCode: .internalServerError)

                        return context.eventLoop.makeSucceededFuture(apigatewayOutput)
                    }
                }
        }

    }
    
    func getLabels(with key: String, context: Lambda.Context) -> EventLoopFuture<Result<ImageLabel, APIError>> {
        guard let imageLabelsTable = Lambda.env("TABLE") else {
            return context.eventLoop.makeSucceededFuture(Result.failure(APIError.getLabelsError))
        }
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let input = DynamoDB.GetItemInput(key: ["image": .s("image")], tableName: imageLabelsTable)
        
        return db.getItem(input, type: ImageLabel.self)
            .flatMap { output in
                guard let imageLabel = output.item else {
                    return context.eventLoop.makeSucceededFuture(Result.failure(APIError.getLabelsError))
                }
                return context.eventLoop.makeSucceededFuture(Result.success(imageLabel))
            }
    }

    func deleteImage(with key: String, context: Lambda.Context) -> EventLoopFuture<Result<String, APIError>> {
        guard let imageLabelsTable = Lambda.env("TABLE") else {
            return context.eventLoop.makeSucceededFuture(Result.failure(APIError.deleteError))
        }
        
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let input = DynamoDB.DeleteItemInput(key: ["image": .s("image")], tableName: imageLabelsTable)
        
        return db.deleteItem(input)
            .flatMap { _ in
                return context.eventLoop.makeSucceededFuture(Result.success("Delete request successfully processed"))
            }
    }
}
