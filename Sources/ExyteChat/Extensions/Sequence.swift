//
//  File.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 05.08.2025.
//

import Foundation

extension Sequence {
    func partitioned(by predicate: (Element) -> Bool) -> (matching: [Element], nonMatching: [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []
        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        return (matching, nonMatching)
    }
}
