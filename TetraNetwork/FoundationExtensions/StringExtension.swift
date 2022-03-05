//
//  StringExtension.swift
//  TetraNetwork
//
//  Created by Son Nguyen on 9/2/21.
//

import Foundation

internal extension String {
    var safeUrlString: String {
        return addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }
}
