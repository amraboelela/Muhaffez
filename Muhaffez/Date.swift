//
//  Date.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 9/9/25.
//

import Foundation

extension Date {
    var logTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: self)
    }
}
