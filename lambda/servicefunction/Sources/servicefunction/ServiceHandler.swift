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

        return promise.futureResult.flatMap {
            let promise = context.eventLoop.makePromise(of: Void.self)
            self.awsClient.shutdown { error in
                if let error = error {
                    promise.fail(error)
                } else {
                    promise.succeed(())
                }
            }
            return promise.futureResult
        }
    }
    
    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        let input = event

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
        guard let imageLabelsTable = Lambda.env("TABLE"), let bucketName = Lambda.env("BUCKET"), let thumbBucketName = Lambda.env("THUMBBUCKET") else {
            return context.eventLoop.makeSucceededFuture(Result.failure(APIError.deleteError))
        }

        let s3 = S3(client: awsClient)
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let input = DynamoDB.DeleteItemInput(key: ["image": .s(key)], tableName: imageLabelsTable)
        
        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucketName, key: key)
        let deleteThumbRequest = S3.DeleteObjectRequest(bucket: thumbBucketName, key: key)

        let futureResponse = db.deleteItem(input)
            .flatMap { _ in
                return s3.deleteObject(deleteObjectRequest)
            }
            .flatMap { _ in
                return s3.deleteObject(deleteThumbRequest)
            }
        
        futureResponse.whenComplete { result in
            switch result {
            case .failure(let error):
                context.logger.info("deleteImage error: \(error.localizedDescription)")
            case .success(let deleteResult):
                context.logger.info("deleteImage success: \(deleteResult)")
            }
        }
        
        return context.eventLoop.makeSucceededFuture(Result<String, APIError>.success("Yes, this compiled, but I have no idea if this was a success or not"))
    }
}
