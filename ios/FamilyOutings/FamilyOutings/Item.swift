//
//  Item.swift
//  FamilyOutings
//
//  Created by itto nagai on 2026/02/09.
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
