//
//  TextStyle.swift
//  JournalMap
//
//  Created by Daniel Farahani on 2/1/2026.
//

import Foundation
import SwiftUI

enum TextStyle {
    case title
    case category
    case body

    var font: Font {
        switch self {
        case .title:
            return .system(size: 24, weight: .bold, design: .default)
        case .category:
            return .system(size: 16, weight: .medium, design: .default)
        case .body:
            return .system(size: 16, weight: .regular, design: .default)
        }
    }
}
