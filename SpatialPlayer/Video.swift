//
//  Video.swift
//  SpatialPlayer
//
//  Created by Alvaro Velad Galvan on 9/4/24.
//

import Foundation


struct Video: Codable, Identifiable {
    enum CodingKeys: CodingKey {
        case url
        case name
    }
    
    var id = UUID()
    var url: String
    var name: String
}
