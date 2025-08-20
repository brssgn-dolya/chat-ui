//
//  File.swift
//  Chat
//
//  Created by Bohdan Yankivskyi on 05.08.2025.
//

import SwiftUI

extension AnyTransition {
    static var scaleAndFade: AnyTransition {
        .scale.combined(with: .opacity)
    }
}
