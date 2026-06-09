//
//  HomeView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Home View
struct HomeView: View {
    let today = Date.now
    @Query(sort: \TripDetails.startDate)
    var upcomingTrips: [TripDetails]
    
    @State private var selectedTrip: TripDetails? = nil
    @State private var navigatetoNewTrip = false
    @State private var appeared = false
    
    @Binding var createdTrip: TripDetails?

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.bottom, 28)

                    if upcomingTrips.isEmpty {
                        emptyState
                    } else {
                        tripList
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
        .navigationDestination(isPresented: $navigatetoNewTrip) {
            NewTripView()
        }
        .navigationDestination(isPresented: Binding(
            get: { createdTrip != nil },
            set: { if !$0 { createdTrip = nil } }
        )) {
            if let trip = createdTrip {
                TripDetailView(trip: trip)
            }
        }
    }
    

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Trips")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 25)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Image(systemName: "airplane.departure")
                        .font(.system(size: 40))
                        .foregroundColor(.stamp)

                    Text("No Upcoming Trip")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(.inkDark)

                    Text("Your travel schedule is blank.\nLet's change that.")
                        .font(.system(size: 14))
                        .foregroundColor(.inkMid)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }

            Spacer()

            VStack(spacing: 6) {
                
                Text("tap the button below to get started")
                    .font(.system(size: 12))
                    .foregroundColor(.inkMid.opacity(0.7))
                    .multilineTextAlignment(.center)

                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.inkMid.opacity(0.5))
            }
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.65)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
    }
    
    

    // MARK: - Trip List
    private var tripList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.stamp)
                .textCase(.uppercase)
                .tracking(1.5)
                .padding(.horizontal, 20)

            ForEach(Array(upcomingTrips.enumerated()), id: \.element.id) { i, trip in
                TripRowCard(trip: trip)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTrip = trip
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(
                        .easeOut(duration: 0.38).delay(0.05 + Double(i) * 0.07),
                        value: appeared
                    )
            }
        }
        .navigationDestination(item: $selectedTrip) { trip in
            TripDetailView(trip: trip)
        }
    }
}

// MARK: - Trip Row Card
struct TripRowCard: View {
    let trip: TripDetails

    private var durationDays: Int {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: trip.startDate)
        let end   = cal.startOfDay(for: trip.endDate)
        return max(1, (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    private var daysUntil: Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: trip.startDate)
        return max(0, cal.dateComponents([.day], from: today, to: start).day ?? 0)
    }

    private var daysUntilLabel: String {
        switch daysUntil {
        case 0:  return "today"
        case 1:  return "day"
        default: return "days"
        }
    }

    private var dateRangeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: trip.startDate)) – \(fmt.string(from: trip.endDate))"
    }

    var body: some View {
        HStack(spacing: 16) {

            // Countdown column
            VStack(spacing: 2) {
                Text("\(daysUntil)")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.stamp)
                Text(daysUntilLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.inkMid)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .frame(width: 44)

            // Accent divider
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.stamp.opacity(0.25))
                .frame(width: 2, height: 52)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(trip.customTripName)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.stamp)
                    Text("\(trip.city), \(trip.country)")
                        .font(.system(size: 12))
                        .foregroundColor(.inkMid)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    badge("\(durationDays)d", icon: "clock")
                    badge(dateRangeString, icon: "calendar")
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.inkMid.opacity(0.4))
        }
        .padding(16)
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.inkDark.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func badge(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.inkMid)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.stampLight)
        .clipShape(Capsule())
    }
}

// MARK: - Preview
//#Preview("Empty State") {
//    HomeView()
//        .modelContainer(for: TripDetails.self, inMemory: true)
//}

#Preview("With Trips") {
    PreviewHomeView()
}

struct PreviewHomeView: View {
    @State private var createdTrip: TripDetails? = nil

    var body: some View {
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try! ModelContainer(
            for: TripDetails.self,
            configurations: config
        )
        
        // Paris Trip
        let trip1 = TripDetails(
            city: "Paris",
            country: "France",
            customTripName: "Bonjour, Paris",
            startDate: Date().addingTimeInterval(86400 * 12),
            endDate: Date().addingTimeInterval(86400 * 18),
            travelVibes: ["🎨 Culture", "🥐 Culinary"],
            budgetLevel: 7,
            tripPace: 4
        )

        // Tokyo Trip
        let trip2 = TripDetails(
            city: "Tokyo",
            country: "Japan",
            customTripName: "Tokyo Drift",
            startDate: Date().addingTimeInterval(86400 * 30),
            endDate: Date().addingTimeInterval(86400 * 38),
            travelVibes: ["🌃 Nightlife", "🛍️ Shopping"],
            budgetLevel: 9,
            tripPace: 8
        )

        // Bali Trip
        let trip3 = TripDetails(
            city: "Bali",
            country: "Indonesia",
            customTripName: "Island Reset",
            startDate: Date().addingTimeInterval(86400 * 5),
            endDate: Date().addingTimeInterval(86400 * 9),
            travelVibes: ["🏖️ Relaxation", "☕ Café Hopping"],
            budgetLevel: 5,
            tripPace: 2
        )

        container.mainContext.insert(trip1)
        container.mainContext.insert(trip2)
        container.mainContext.insert(trip3)

        return HomeView(createdTrip: $createdTrip)
            .modelContainer(container)
    }
}
//#Preview("With Trips") {
//    
//    @Previewable @State var createdTrip: TripDetails? = nil
//
//    let config = ModelConfiguration(
//        isStoredInMemoryOnly: true
//    )
//
//    let container = try! ModelContainer(
//        for: TripDetails.self,
//        configurations: config
//    )
//
//    // Paris Trip
//    let trip1 = TripDetails(
//        city: "Paris",
//        country: "France",
//        customTripName: "Bonjour, Paris",
//        startDate: Date().addingTimeInterval(86400 * 12),
//        endDate: Date().addingTimeInterval(86400 * 18),
//        travelVibes: ["🎨 Culture", "🥐 Culinary"],
//        budgetLevel: 7,
//        tripPace: 4
//    )
//
//    // Tokyo Trip
//    let trip2 = TripDetails(
//        city: "Tokyo",
//        country: "Japan",
//        customTripName: "Tokyo Drift",
//        startDate: Date().addingTimeInterval(86400 * 30),
//        endDate: Date().addingTimeInterval(86400 * 38),
//        travelVibes: ["🌃 Nightlife", "🛍️ Shopping"],
//        budgetLevel: 9,
//        tripPace: 8
//    )
//
//    // Bali Trip
//    let trip3 = TripDetails(
//        city: "Bali",
//        country: "Indonesia",
//        customTripName: "Island Reset",
//        startDate: Date().addingTimeInterval(86400 * 5),
//        endDate: Date().addingTimeInterval(86400 * 9),
//        travelVibes: ["🏖️ Relaxation", "☕ Café Hopping"],
//        budgetLevel: 5,
//        tripPace: 2
//    )
//
//    container.mainContext.insert(trip1)
//    container.mainContext.insert(trip2)
//    container.mainContext.insert(trip3)
//
//    HomeView(createdTrip: $createdTrip)
//        .modelContainer(container)
//}
