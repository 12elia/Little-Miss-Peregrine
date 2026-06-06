//
//  Constants.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 27/05/26.
//

//import Foundation
import SwiftUI

struct Constants {

    static let homeString = "Home"
    static let createString = "Create"
    static let libraryString = "Library"

    static let homeIconString = "house"
    static let createIconString = "sparkles"
    static let libraryIconString = "doc"

    static let noTripString = "No Upcoming Trip"
    static let noTripIconString = "airplane.departure"

    static let noTripDescString = "You dont have any travel planned yet"
}

extension Color {
    
    static let sand = Color(
        red: 0.97,
        green: 0.94,
        blue: 0.88
    )
    
    static let cardWhite = Color(
        red: 1.00,
        green: 0.99,
        blue: 0.97
    )
    
    static let inkDark = Color(
        red: 0.13,
        green: 0.11,
        blue: 0.09
    )
    
    static let inkMid = Color(
        red: 0.45,
        green: 0.41,
        blue: 0.36
    )
    
    static let stamp = Color(
        red: 0.96,
        green: 0.44,
        blue: 0.14
    )
    
    static let stampLight = Color(
        red: 0.96,
        green: 0.44,
        blue: 0.14
    ).opacity(0.12)
    
    static let divider = Color(
        red: 0.87,
        green: 0.83,
        blue: 0.77
    )
    
}

struct AppAppearance {

    static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        let itemAppearance = UITabBarItemAppearance()

        // Unselected
        itemAppearance.normal.iconColor = UIColor(Color.divider)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.divider)
        ]

        // Selected
        itemAppearance.selected.iconColor = UIColor(Color.inkMid)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.inkMid)
        ]

        appearance.stackedLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
