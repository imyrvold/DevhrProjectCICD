//
//  File.swift
//  
//
//  Created by Ivan C Myrvold on 11/04/2021.
//

import Foundation
import SotoDynamoDB

public class ImageLabelService {
    let db: DynamoDB
    let tableName: String
    
    public init(db: DynamoDB, tableName: String) {
        self.db = db
        self.tableName = tableName
    }
    
//    public func getImageLabel(id: String) -> EventLoopFuture<ImageLabel> {
//        
//    }
}
