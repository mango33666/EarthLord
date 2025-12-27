//
//  Item.swift
//  EarthLord
//
//  Created by 芒果888 on 2025/12/27.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
