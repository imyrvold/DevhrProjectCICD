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

struct LabelsOutput: Codable {
    let labels: [String]
}

struct DeleteOutput: Codable {
    let result: String
}

struct ServiceHandler: EventLoopLambdaHandler {
    typealias In = Input
    typealias Out = APIGateway.Response
    
    let awsClient: AWSClient

    init(context: Lambda.InitializationContext) {
        context.logger.info("init 1")
        self.awsClient = AWSClient(httpClientProvider: .createNewWithEventLoopGroup(context.eventLoop))
        context.logger.info("init 2")
    }

    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        context.logger.info("shutdown 1")
        let promise = context.eventLoop.makePromise(of: Void.self)
        context.logger.info("shutdown 2")
        awsClient.shutdown { error in
            context.logger.info("shutdown 3")
            if let error = error {
                context.logger.info("shutdown 4")
                promise.fail(error)
            } else {
                context.logger.info("shutdown 5")
                promise.succeed(())
            }
        }
        context.logger.info("shutdown 6")

        return promise.futureResult.flatMap {
            context.logger.info("shutdown 7")
            let promise = context.eventLoop.makePromise(of: Void.self)
            context.logger.info("shutdown 8")
            self.awsClient.shutdown { error in
                context.logger.info("shutdown 9")
                if let error = error {
                    context.logger.info("shutdown 10")
                    promise.fail(error)
                } else {
                    context.logger.info("shutdown 11")
                    promise.succeed(())
                }
            }
            context.logger.info("shutdown 12")
            return promise.futureResult
        }
    }
    
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        context.logger.info("handle 1")
        let input = event
        context.logger.info("handle 2")

        switch input.action {
        case .getLabels:
            return getLabels(with: input.key, context: context)
                .flatMap { result in
                    switch result {
                    case .success(let imageLabel):
                        let labels = imageLabel.labels
                        
                        let output = LabelsOutput(labels: labels)
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
    
    func getLabels(with key: String, context: Lambda.Context) -> EventLoopFuture<Result<RekEntry, APIError>> {
        guard let imageLabelsTable = Lambda.env("TABLE") else {
            return context.eventLoop.makeSucceededFuture(Result.failure(APIError.getLabelsError))
        }
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let input = DynamoDB.GetItemInput(key: ["image": .s(key)], tableName: imageLabelsTable)
        
        return db.getItem(input, type: RekEntry.self)
            .flatMap { output in
                guard let rekEntry = output.item else {
                    return context.eventLoop.makeSucceededFuture(Result.failure(APIError.getLabelsError))
                }
                return context.eventLoop.makeSucceededFuture(Result.success(rekEntry))
            }
    }

    func deleteImage(with key: String, context: Lambda.Context) -> EventLoopFuture<Result<String, APIError>> {
        guard let imageLabelsTable = Lambda.env("TABLE") else {
            return context.eventLoop.makeSucceededFuture(Result.failure(APIError.deleteError))
        }
        
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let input = DynamoDB.DeleteItemInput(key: ["image": .s(key)], tableName: imageLabelsTable)
        
        return db.deleteItem(input)
            .flatMap { _ in
                return context.eventLoop.makeSucceededFuture(Result.success("Delete request successfully processed"))
            }
    }
}
