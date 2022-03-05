//
//  TetraNetworkCachable.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation

/// Enum sepecifying the priority of cache. Cache data with lower priority will be removed first in the case of low cache capacity
public enum TetraNetworkCachePriority: Int {
    case lowest, low, medium, high, highest
}

/// Add this protocol conformance to your request if you want to use buffering feature
public protocol TetraNetworkCachable {
    var hash: AnyHashable { get }
}
