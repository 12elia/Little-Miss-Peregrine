//
//  LibraryView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Library View
struct LibraryView: View {
    // Only show trips that have ended
    @Query(
        sort: \TripDetails.endDate,
        order: .reverse
    ) var allTrips: [TripDetails]

    private var pastTrips: [TripDetails] {
        let now = Date()
        return allTrips.filter { $0.endDate < now }
    }

    @State private var appeared = false
    @State private var selectedTrip: TripDetails? = nil

    // MARK: Dummy data flag — remove when real data flows in
    private let useDummy = true

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.bottom, 20)

                    if displayTrips.isEmpty {
                        emptyState
                    } else {
                        scrapbookGrid
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .navigationDestination(item: $selectedTrip) { trip in
            ScrapbookDetailView(trip: trip)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    // Use dummy trips if no real past trips exist yet
    private var displayTrips: [TripDetails] {
        if useDummy && pastTrips.isEmpty { return DummyData.pastTrips }
        return pastTrips
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
//                Text("memories collected")
//                    .font(.system(size: 12, weight: .medium))
//                    .foregroundColor(.inkMid)
                Text("Album")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
            }
            Spacer()
            // Trip count badge
            Text("\(displayTrips.count) trips")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.stamp)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.stampLight)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.stampLight)
                    .frame(width: 90, height: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.stamp.opacity(0.2),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    )
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.stamp.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text("No past trips yet")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
                Text("Completed trips will appear here\nas scrapbooks.")
                    .font(.system(size: 13))
                    .foregroundColor(.inkMid)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .frame(height: UIScreen.main.bounds.height * 0.55)
    }

    // MARK: - Scrapbook Grid
    private var scrapbookGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scrapbooks")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.stamp)
                .textCase(.uppercase)
                .tracking(2)
                .padding(.horizontal, 20)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(displayTrips.enumerated()), id: \.element.id) { i, trip in
                    ScrapbookCard(trip: trip)
                        .onTapGesture { selectedTrip = trip }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.38).delay(Double(i) * 0.06), value: appeared)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Scrapbook Card
struct ScrapbookCard: View {
    let trip: TripDetails

    // Slight deterministic tilt for physical scrapbook feel
    private var tilt: Double {
        let seed = trip.customTripName.count % 5
        return [-2.0, -1.0, 0.0, 1.0, 2.0][seed]
    }

    private var monthYear: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM ''yy"
        return fmt.string(from: trip.startDate).uppercased()
    }

    private var completedCount: Int {
        trip.itineraryItems.filter { $0.isCompleted }.count
    }

    // Show first proof photo if available
    private var coverImage: UIImage? {
        trip.itineraryItems
            .filter { $0.isCompleted && $0.proofPhotoData != nil }
            .compactMap { UIImage(data: $0.proofPhotoData!) }
            .first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .topTrailing) {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 130)
                        .clipped()
                } else {
                    // Placeholder cover with graph paper texture
                    ZStack {
                        Color.stampLight
                        Canvas { ctx, size in
                            let sp: CGFloat = 10
                            var x: CGFloat = 0
                            while x < size.width {
                                var p = Path()
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: size.height))
                                ctx.stroke(p, with: .color(Color.stamp.opacity(0.08)), lineWidth: 0.5)
                                x += sp
                            }
                            var y: CGFloat = 0
                            while y < size.height {
                                var p = Path()
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: size.width, y: y))
                                ctx.stroke(p, with: .color(Color.stamp.opacity(0.08)), lineWidth: 0.5)
                                y += sp
                            }
                        }
                        Image(systemName: "airplane")
                            .font(.system(size: 28))
                            .foregroundColor(.stamp.opacity(0.3))
                            .rotationEffect(.degrees(-35))
                    }
                    .frame(height: 130)
                }

                // Month stamp
                Text(monthYear)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.stamp)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.cardWhite.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
            .frame(height: 130)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.customTripName)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
                    .lineLimit(1)

                Text("\(trip.city), \(trip.country)")
                    .font(.system(size: 11))
                    .foregroundColor(.inkMid)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.stamp)
                    Text("\(completedCount) stamped")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.stamp)
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.inkDark.opacity(0.07), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
        .rotationEffect(.degrees(tilt))
    }
}

// MARK: - Dummy Data
//struct DummyData {
//    static var pastTrips: [TripDetails] {
//        let cal = Calendar.current
//
//        let t1 = TripDetails(
//            city: "Tokyo", country: "Japan",
//            customTripName: "Tokyo Spring 2025",
//            startDate: cal.date(byAdding: .month, value: -8, to: Date())!,
//            endDate:   cal.date(byAdding: .month, value: -7, to: Date())!,
//            travelVibes: ["Culinary", "Culture", "Photography"],
//            budgetLevel: 6, tripPace: 7
//        )
//
//        let t2 = TripDetails(
//            city: "Barcelona", country: "Spain",
//            customTripName: "Barcelona Solo",
//            startDate: cal.date(byAdding: .month, value: -5, to: Date())!,
//            endDate:   cal.date(byAdding: .month, value: -5, to: Date())!.addingTimeInterval(86400 * 5),
//            travelVibes: ["History", "Culinary", "Nightlife"],
//            budgetLevel: 5, tripPace: 6
//        )
//
//        let t3 = TripDetails(
//            city: "Kyoto", country: "Japan",
//            customTripName: "Kyoto Autumn",
//            startDate: cal.date(byAdding: .month, value: -3, to: Date())!,
//            endDate:   cal.date(byAdding: .month, value: -3, to: Date())!.addingTimeInterval(86400 * 4),
//            travelVibes: ["Nature", "History", "Photography"],
//            budgetLevel: 4, tripPace: 3
//        )
//
//        let t4 = TripDetails(
//            city: "Amsterdam", country: "Netherlands",
//            customTripName: "Amsterdam Wander",
//            startDate: cal.date(byAdding: .month, value: -1, to: Date())!,
//            endDate:   cal.date(byAdding: .day, value: -20, to: Date())!,
//            travelVibes: ["Culture", "Café Hopping", "Photography"],
//            budgetLevel: 7, tripPace: 4
//        )
//
//        // Add some dummy completed items
//        [t1, t2, t3, t4].forEach { trip in
//            let venues = ["Central Café", "Old Museum", "Night Market", "Riverside Walk", "Art Gallery"]
//            let photos = ["dummy_1", "dummy_2", "dummy_3", "dummy_4"]
//            venues.enumerated().forEach { i, venue in
//                let item = ItineraryItem(
//                    activityName: "Visit",
//                    venueName: venue,
//                    category: .sightseeing,
//                    date: trip.startDate.addingTimeInterval(Double(i) * 3600),
//                    recommendedTime: trip.startDate.addingTimeInterval(Double(i) * 3600),
//                    trip: trip
//                )
//                item.isCompleted = i < 3
//
//                // Attach dummy photo if asset exists
//                if i < 3, let img = UIImage(named: photos[i % photos.count]) {
//                    item.proofPhotoData = img.jpegData(compressionQuality: 0.8)
//                }
//
//                trip.itineraryItems.append(item)
//            }
//        }
//
//        return [t1, t2, t3, t4]
//    }
//}


struct DummyData {

    static var pastTrips: [TripDetails] {
        let cal = Calendar.current

        let t1 = TripDetails(
            city: "Paris",
            country: "France",
            customTripName: "Nadia in Paris",
            startDate: cal.date(byAdding: .month, value: -8, to: Date())!,
            endDate: cal.date(byAdding: .month, value: -7, to: Date())!,
            travelVibes: ["Culinary", "Culture", "Photography"],
            budgetLevel: 6,
            tripPace: 7
        )

        let t2 = TripDetails(
            city: "Barcelona",
            country: "Spain",
            customTripName: "Barcelona Solo",
            startDate: cal.date(byAdding: .month, value: -5, to: Date())!,
            endDate: cal.date(byAdding: .month, value: -5, to: Date())!.addingTimeInterval(86400 * 5),
            travelVibes: ["History", "Culinary", "Nightlife"],
            budgetLevel: 5,
            tripPace: 6
        )

        let t3 = TripDetails(
            city: "Curug",
            country: "Indonesia",
            customTripName: "Curug Calls",
            startDate: cal.date(byAdding: .month, value: -3, to: Date())!,
            endDate: cal.date(byAdding: .month, value: -3, to: Date())!.addingTimeInterval(86400 * 4),
            travelVibes: ["Nature", "History", "Photography"],
            budgetLevel: 4,
            tripPace: 3
        )

        let t4 = TripDetails(
            city: "Melbourne",
            country: "Australia",
            customTripName: "Melbourne Marathon",
            startDate: cal.date(byAdding: .month, value: -1, to: Date())!,
            endDate: cal.date(byAdding: .day, value: -20, to: Date())!,
            travelVibes: ["Culture", "Café Hopping", "Photography"],
            budgetLevel: 7,
            tripPace: 4
        )

        populateTrip(
            t1,
            photos: ["dummy_1", "dummy_2", "dummy_3"]
        )

        populateTrip(
            t2,
            photos: ["dummy_4", "dummy_4", "dummy_4"]
        )

        populateTrip(
            t3,
            photos: ["dummy_5", "dummy_4", "dummy_4"]
        )

        populateTrip(
            t4,
            photos: ["dummy_7", "dummy_4", "dummy_4"]
        )

        return [t1, t2, t3, t4]
    }

    private static func populateTrip(
        _ trip: TripDetails,
        photos: [String]
    ) {
        let venues = [
            "Central Café",
            "Old Museum",
            "Night Market",
            "Riverside Walk",
            "Art Gallery"
        ]

        for (index, venue) in venues.enumerated() {

            let item = ItineraryItem(
                activityName: "Visit",
                venueName: venue,
                category: .sightseeing,
                date: trip.startDate.addingTimeInterval(Double(index) * 3600),
                recommendedTime: trip.startDate.addingTimeInterval(Double(index) * 3600),
                trip: trip
            )

            item.isCompleted = index < 3

            if index < 3,
               let image = UIImage(named: photos[index]) {
                item.proofPhotoData = image.jpegData(compressionQuality: 0.85)
            }

            trip.itineraryItems.append(item)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        LibraryView()
    }
    .modelContainer(for: [TripDetails.self, ItineraryItem.self], inMemory: true)
}
