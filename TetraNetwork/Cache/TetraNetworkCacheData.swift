//
//  TetraNetworkCacheData.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation

internal struct TetraNetworkCacheData {
    let data: Data
    let expirationTime: Date
    let priority: TetraNetworkCachePriority
    
    var isValid: Bool {
        return Date().compare(expirationTime) != .orderedDescending
    }
}
