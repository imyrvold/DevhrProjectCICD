//
//  File.swift
//  
//
//  Created by Ivan C Myrvold on 18/04/2021.
//

import Foundation

struct Input: Codable {
    enum Action: String, Codable {
        case getLabels, deleteImage
    }

    let action: Action
    let key: String
}

