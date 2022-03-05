//
//  TetraRequestConfig.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/5/22.
//

import Foundation

/// You need to supply this config every time you make a request
public struct TetraRequestConfig {
    internal let shouldCache: Bool
    internal let useCache: Bool
    internal let bufferEnabled: Bool
    
    internal let cacheDuration: TimeInterval
    internal let cachePriority: TetraNetworkCachePriority
    
    public init(shouldCache: Bool = true,
                useCache: Bool = true,
                bufferEnabled: Bool = true,
                cacheDuration: TimeInterval = 300,
                cachePriority: TetraNetworkCachePriority = .medium) {
        self.shouldCache = shouldCache
        self.useCache = useCache
        self.bufferEnabled = bufferEnabled
        self.cacheDuration = cacheDuration
        self.cachePriority = cachePriority
    }
}
