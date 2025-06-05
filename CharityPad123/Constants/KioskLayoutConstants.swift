//
//  KioskLayoutConstants.swift
//  CharityPad123
//
//  Created by Zalman Rodkin on 5/29/25.
//

import SwiftUI

struct KioskLayoutConstants {
    // Consistent spacing and positioning
    static let topContentOffset: CGFloat = 20         // Distance from top to main content       
    static let titleBottomSpacing: CGFloat = 40       // Space below main title
    static let contentHorizontalPadding: CGFloat = 20 // Side margins
    static let maxContentWidth: CGFloat = 800         // Max width for content
    static let buttonSpacing: CGFloat = 16            // Space between buttons
    static let bottomSafeArea: CGFloat = 40           // Space from bottom
    
    // Font sizes (keeping your existing sizes)
    static let titleFontSize: CGFloat = 50
    static let titleFontSizeCompact: CGFloat = 32
    static let buttonFontSize: CGFloat = 24
    static let buttonFontSizeCompact: CGFloat = 20
    
    // Button dimensions
    static let buttonHeight: CGFloat = 80
    static let buttonHeightCompact: CGFloat = 60
}
