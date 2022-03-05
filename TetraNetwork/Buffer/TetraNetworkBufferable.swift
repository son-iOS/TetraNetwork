//
//  TetraNetworkBufferable.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation

/// Add this protocol conformance to your request if you want to use buffering feature
public protocol TetraNetworkBufferable {
    var hash: AnyHashable { get }
}
