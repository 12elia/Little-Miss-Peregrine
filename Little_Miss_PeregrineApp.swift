//
//  Little_Miss_PeregrineApp.swift
//  Little Miss Peregrine
//
//  Created by Nadia on 06/06/26.
//
//
//import SwiftUI
//import SwiftData
//
//@main
//struct Little_Miss_PeregrineApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//        .modelContainer(for: [TripDetails.self, ItineraryItem.self])
//    }
//}


//
//  LittleMissPeregrineApp.swift
//

import SwiftUI
import SwiftData

@main
struct LittleMissPeregrineApp: App {
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            if showLaunch {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                showLaunch = false
                            }
                        }
                    }
            } else {
                ContentView()
                    .modelContainer(for: [TripDetails.self, ItineraryItem.self])
            }
        }
    }
}
