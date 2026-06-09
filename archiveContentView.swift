////
////  ContentView.swift
////  LittleMissPeregrine
////
////  Created by Nadia on 28/05/26.
////
//
//import SwiftData
//import SwiftUI
//
//struct ContentView: View {
//    @State private var newTripViewID = UUID()
//    @State private var selectedTab: Int = 0
//    @State private var createdTrip: TripDetails? = nil
//
//    var body: some View {
//        TabView(selection: $selectedTab) {
//            // Home
//            NavigationStack {
//                HomeView(createdTrip: $createdTrip)
//            }
//            .tabItem {
//                Label(Constants.homeString, systemImage: Constants.homeIconString)
//            }
//            .tag(0)
//
//            // Create
//            NavigationStack {
//                NewTripView(onTripCreated: { trip in
//                    createdTrip = trip
//                    newTripViewID = UUID()
//                    selectedTab = 0
//                })
//                .id(newTripViewID)
//            }
//            .tabItem {
//                Label(Constants.createString, systemImage: Constants.createIconString)
//            }
//            .tag(1)
//
//            // Library
//            NavigationStack {
//                LibraryView()
//            }
//            .tabItem {
//                Label(Constants.libraryString, systemImage: Constants.libraryIconString)
//            }
//            .tag(2)
//
//            // Debug (only in DEBUG builds)
//            #if DEBUG
//            NavigationStack {
//                EXIFDebugView()
//            }
//            .tabItem {
//                Label("Debug", systemImage: "wrench.and.screwdriver.fill")
//            }
//            .tag(3)
//            #endif
//        }
//        .tint(.inkMid)
//        .onChange(of: selectedTab) {
//            if selectedTab == 1 {
//                newTripViewID = UUID()
//            }
//        }
//        .onAppear {
//            AppAppearance.configureTabBar()
//        }
//    }
//}
//
//// MARK: - Preview
//
//struct PreviewContainerView: View {
//
//    let container: ModelContainer
//
//    init() {
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//
//        container = try! ModelContainer(
//            for: TripDetails.self,
//            ItineraryItem.self,
//            configurations: config
//        )
//
//        let trip1 = TripDetails(
//            city: "Paris",
//            country: "France",
//            customTripName: "Bonjour, Paris",
//            startDate: Date().addingTimeInterval(86400 * 12),
//            endDate: Date().addingTimeInterval(86400 * 18),
//            travelVibes: ["🎨 Culture", "🥐 Culinary"],
//            budgetLevel: 7,
//            tripPace: 4
//        )
//
//        let trip2 = TripDetails(
//            city: "Tokyo",
//            country: "Japan",
//            customTripName: "Tokyo Drift",
//            startDate: Date().addingTimeInterval(86400 * 30),
//            endDate: Date().addingTimeInterval(86400 * 38),
//            travelVibes: ["🌃 Nightlife", "🛍️ Shopping"],
//            budgetLevel: 9,
//            tripPace: 8
//        )
//
//        let trip3 = TripDetails(
//            city: "Bali",
//            country: "Indonesia",
//            customTripName: "Island Reset",
//            startDate: Date().addingTimeInterval(86400 * 5),
//            endDate: Date().addingTimeInterval(86400 * 9),
//            travelVibes: ["🏖️ Relaxation", "☕ Café Hopping"],
//            budgetLevel: 5,
//            tripPace: 2
//        )
//
//        container.mainContext.insert(trip1)
//        container.mainContext.insert(trip2)
//        container.mainContext.insert(trip3)
//    }
//
//    var body: some View {
//        ContentView()
//            .modelContainer(container)
//    }
//}
//
//#Preview("With Trips") {
//    PreviewContainerView()
//}
