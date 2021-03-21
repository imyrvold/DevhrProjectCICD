//
//  RekHandler.swift
//  
//
//  Created by Ivan C Myrvold on 20/03/2021.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import SotoRekognition
import SotoDynamoDB

struct RekHandler: EventLoopLambdaHandler {
    typealias In = AWSLambdaEvents.S3.Event
    typealias Out = Void
    
    let minConfidence: Float = 50

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

    func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        guard let record = event.records.first else { return context.eventLoop.makeFailedFuture(APIError.requestError) }
        let safeKey = record.s3.object.key.replacingOccurrences(of: "%3A", with: ":")
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let s3Object = Rekognition.S3Object(bucket: record.s3.bucket.name, name: safeKey)
        let image = Rekognition.Image(s3Object: s3Object)
        let rekognitionClient = Rekognition(client: awsClient)
        let detectLabelsRequest = Rekognition.DetectLabelsRequest(image: image, maxLabels: 10, minConfidence: minConfidence)

        return rekognitionClient.detectLabels(detectLabelsRequest)
            .flatMap { detectLabelsResponse -> EventLoopFuture<Void> in
                guard let rekLabels = detectLabelsResponse.labels,
                      let imageLabelsTable = Lambda.env("TABLE") else {
                    return context.eventLoop.makeSucceededFuture(())
                }
                
                // Instantiate a table resource object of our environment variable
                let labels = rekLabels.compactMap { $0.name }
                let rekEntry = RekEntry(image: safeKey, labels: labels)
                let putRequest = DynamoDB.PutItemCodableInput(item: rekEntry, tableName: imageLabelsTable)
                
                // Put item into table
                return db.putItem(putRequest)
                    .flatMap { result in
                        return context.eventLoop.makeSucceededFuture(())
                    }
            }.map { _ in }
    }
        
}
