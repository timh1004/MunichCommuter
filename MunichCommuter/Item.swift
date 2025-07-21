//
//  Item.swift
//  MunichCommuter
//
//  Created by Tim Haug on 21.07.25.
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
