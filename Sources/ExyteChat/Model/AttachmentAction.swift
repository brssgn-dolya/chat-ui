//
//  File.swift
//  
//
//  Created by Boris on 16.09.2024.
//

import Foundation

public enum AttachmentAction: Hashable, CaseIterable {
    case gallery
    case file
    
    var title: String {
        switch self {
        case .gallery:
            return "🏞️ Галерея"
        case .file:
            return "📄 Файл"
        }
    }
}
