//
//  File.swift
//  
//
//  Created by Ivan C Myrvold on 11/04/2021.
//

import Foundation
import SotoDynamoDB

public struct Label: Codable {
    public let name: String
    
    public struct DynamoDBField {
        static let name = "name"
    }
}

//extension Label {
//    public var dynamoDBDictionary: [String: DynamoDB.AttributeValue] {
//        let dictionary = [
//            DynamoDBField.name: DynamoDB.AttributeValue.s(name)
//        ]
//        
//        return dictionary
//    }
//}

public struct ImageLabel: Codable {
    public let image: String
    public let labels: [Label]
    
    public struct DynamoDBField {
        static let image = "image"
        static let labels = "labels"
//        static let isCompleted = "isCompleted"
    }
}

//extension ImageLabel {
//    public var dynamoDBDictionary: [String: DynamoDB.AttributeValue] {
//        let labelsAttributes: [DynamoDB.AttributeValue] = labels.map { DynamoDB.AttributeValue.s($0.name) }
//        let dictionary = [
//            DynamoDBField.image: DynamoDB.AttributeValue.s(image),
//            DynamoDBField.labels: DynamoDB.AttributeValue.l(labelsAttributes)
//        ]
//
//        return dictionary
//    }
//    
//    public init(dictionary: [String: DynamoDB.AttributeValue]) throws {
//        guard let image: DynamoDB.AttributeValue = dictionary[DynamoDBField.image], let labels = dictionary[DynamoDBField.labels] else { throw APIError.decodingError }
//        
//        self.image = DynamoDB.AttributeValue.s(image)
//        self.labels = labels
//    }
//}
