//
//  ContentView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var newTripViewID = UUID()
    @State private var selectedTab: Int = 0
    @State private var createdTrip: TripDetails? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home
            NavigationStack {
                HomeView(createdTrip: $createdTrip)
            }
            .tabItem {
                Label(Constants.homeString, systemImage: Constants.homeIconString)
            }
            .tag(0)

            // Create
            NavigationStack {
                NewTripView(onTripCreated: { trip in
                    createdTrip = trip
                    newTripViewID = UUID()  // reset form for next time
                    selectedTab = 0
                })
                .id(newTripViewID)          // ← this is what was missing
            }
            .tabItem {
                Label(Constants.createString, systemImage: Constants.createIconString)
            }
            .tag(1)

            // Library
            NavigationStack {
                LibraryView()
            }
            .tabItem {
                Label(Constants.libraryString, systemImage: Constants.libraryIconString)
            }
            .tag(2)
        }
        .tint(.inkMid)
        .onChange(of: selectedTab) {
            if selectedTab == 1 {
                newTripViewID = UUID()
            }
        }
        .onAppear {
            AppAppearance.configureTabBar()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [TripDetails.self, ItineraryItem.self],
            inMemory: true
        )
}
