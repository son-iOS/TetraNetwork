//
//  TetraNetworkError.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 3/1/22.
//

import Foundation

/// `TetraNetwork` only emit this type of error.
public protocol TetraNetworkError: Error {
    /// Create an error from the raw response of a url request
    init(from respose: TetraNetworkRawResponse)
}
