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
import SotoS3
import Foundation
#if os(macOS)
import CImageMagickMac
#else
import CImageMagick
#endif

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
        let db = DynamoDB(client: awsClient, region: .euwest1)
        let rekognitionClient = Rekognition(client: awsClient)
        guard let thumbBucket = Lambda.env("THUMBBUCKET") else { return context.eventLoop.makeSucceededVoidFuture() }

        let futureRecords: [AWSLambdaEvents.S3.Event.Record] = event.records

        let futureRecordsResult = futureRecords.map { record -> EventLoopFuture<Out> in
            let safeKey = record.s3.object.key.replacingOccurrences(of: "%3A", with: ":")
            let s3Object = Rekognition.S3Object(bucket: record.s3.bucket.name, name: safeKey)
            let image = Rekognition.Image(s3Object: s3Object)
            let detectLabelsRequest = Rekognition.DetectLabelsRequest(image: image, maxLabels: 10, minConfidence: minConfidence)


            return getImage(of: record.s3.bucket.name, with: safeKey, context: context)
                .flatMap { output in
                    let body = output.body
                    guard let data = body?.asData() else { return context.eventLoop.makeSucceededVoidFuture() }
                    context.logger.info("handle 1")
                    guard let thumbnail = createThumbnail(for: data, context: context) else { return context.eventLoop.makeSucceededVoidFuture() }
                    context.logger.info("handle got thumbnail")

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
                                    context.logger.info("handle thumbBucket: \(thumbBucket) safeKey: \(safeKey)")

                                    return saveThumbnail(in: thumbBucket, with: safeKey, for: thumbnail).map { _ in }
                                }
                        }
                }
        }
        
        return EventLoopFuture<Out>.andAllSucceed(futureRecordsResult, on: context.eventLoop)
    }
    
    func createThumbnail(for data: Data, context: Lambda.Context) -> Data? {
        let fileManager = FileManager.default
        let path = "/tmp/image.jpeg"
        let thumbnailpath = "/tmp/thumbnail.jpeg"
        let bool = fileManager.createFile(atPath: path, contents: data, attributes: nil)

        MagickWandGenesis()
        let wand = NewMagickWand()

        let status: MagickBooleanType = MagickReadImage(wand, path)
        if status == MagickFalse {
            context.logger.info("Error reading the image")
        } else {
            let width = MagickGetImageWidth(wand)
            let height = MagickGetImageHeight(wand)
            let newHeight = 100
            let newWidth = 100 * width / height
            context.logger.info("createThumbnail width: \(width) height: \(height)")
            MagickResizeImage(wand, newWidth, newHeight, LanczosFilter,1.0)
            context.logger.info("createThumbnail newWidth: \(newWidth) newHeight: \(newHeight)")
            MagickWriteImage(wand, thumbnailpath)
        }
        DestroyMagickWand(wand)
        MagickWandTerminus()
        
        return fileManager.contents(atPath: thumbnailpath)
    }
    
    func getImage( of bucket: String, with thekey: String, context: Lambda.Context) -> EventLoopFuture<SotoS3.S3.GetObjectOutput> {
        let s3 = S3(client: awsClient)
        let safeKey = thekey.replacingOccurrences(of: "%3A", with: ":")
        guard let key = safeKey.removingPercentEncoding else { return context.eventLoop.makeSucceededFuture(S3.GetObjectOutput()) }
        let tmpKey = key.replacingOccurrences(of: "/", with: "")
        let downloadPath = "/tmp/\(UUID().uuidString)\(tmpKey)"
        let uploadPath = "/tmp/resised-\(tmpKey)"
        let getObjectRequest = S3.GetObjectRequest(bucket: bucket, key: key)

        return s3.getObject(getObjectRequest)
    }

    func saveThumbnail(in bucket: String, with thekey: String, for data: Data) -> EventLoopFuture<SotoS3.S3.PutObjectOutput> {
        let s3 = S3(client: awsClient)
        let bodyData = AWSPayload.data(data)
        
        let putRequest = SotoS3.S3.PutObjectRequest(
            acl: S3.ObjectCannedACL.publicRead,
            body: bodyData,
            bucket: bucket,
            key: thekey
        )
        
        return s3.putObject(putRequest)
    }
            
}
