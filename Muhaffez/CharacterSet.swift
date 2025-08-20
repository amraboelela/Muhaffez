//
//  CharacterSet.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/19/25.
//

import Foundation

extension CharacterSet {
    static let arabicDiacritics: CharacterSet = {
        var set = CharacterSet()
        // Harakat: fatha, damma, kasra, sukun, shadda, etc.
        set.insert(charactersIn: "\u{064B}"..."\u{065F}")
        // dagger alif
        set.insert("\u{0670}")
        return set
    }()
}
