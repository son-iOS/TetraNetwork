//
//  ErrorExtension.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 9/2/21.
//

import Foundation

public extension Error {
    var isNoInternetError: Bool {
        _code == NSURLErrorNotConnectedToInternet
    }
}
