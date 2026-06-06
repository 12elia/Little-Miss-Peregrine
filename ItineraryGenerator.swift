//
//  ItineraryGenerator.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//
//  HOW TO SET UP BEFORE THIS FILE WORKS:
//  ──────────────────────────────────────
//  1. In Xcode, click your project in the navigator (top of the file tree)
//  2. Select your app Target → Info tab
//  3. Add a new row: "Privacy - Location When In Use Usage Description"
//     Value: "Little Miss Peregrine uses your location to verify you visited each spot."
//  4. That's it — no API keys, no billing, all Apple-native.
//

import Foundation
import MapKit
import CoreLocation
import SwiftData
import Combine

// MARK: - Errors
enum GeneratorError: LocalizedError {
    case geocodingFailed
    case noResultsFound
    case modelContextMissing

    var errorDescription: String? {
        switch self {
        case .geocodingFailed:      return "Couldn't find that city on the map."
        case .noResultsFound:       return "No places found for your selected vibes."
        case .modelContextMissing:  return "Database context unavailable."
        }
    }
}

// MARK: - Itinerary Generator
/// Generates a full ItineraryItem schedule for a TripDetails object.
/// Call `generate(for:in:)` from a SwiftUI view after creating the trip.
@MainActor
final class ItineraryGenerator: ObservableObject {

    @Published var isGenerating = false
    @Published var progress: Double = 0          // 0.0 → 1.0 for a progress bar
    @Published var statusMessage = ""

    // MARK: - Entry Point
    /// Main function. Call this after saving a new TripDetails to SwiftData.
    func generate(for trip: TripDetails, in context: ModelContext) async throws {
        isGenerating = true
        progress     = 0
        defer { isGenerating = false }

        // ── Step 1: Geocode the city into a coordinate region ──────────────
        statusMessage = "Finding \(trip.city) on the map…"
        let region = try await geocode(city: trip.city, country: trip.country)
        progress = 0.15

        // ── Step 2: Search for POIs per vibe ───────────────────────────────
        statusMessage = "Discovering places…"
        let searchTerms = searchTerms(for: trip.travelVibes)
        var allPOIs: [POI] = []

        for (i, term) in searchTerms.enumerated() {
            let results = await search(for: term, in: region)
            allPOIs.append(contentsOf: results)
            progress = 0.15 + 0.40 * (Double(i + 1) / Double(searchTerms.count))
        }

        // Deduplicate by name (MKLocalSearch can return overlapping results)
        allPOIs = deduplicated(allPOIs)

        guard !allPOIs.isEmpty else { throw GeneratorError.noResultsFound }

        // ── Step 3: Filter by budget ────────────────────────────────────────
        statusMessage = "Matching your budget…"
        let filtered = filterByBudget(allPOIs, level: trip.budgetLevel)
        progress = 0.60

        // ── Step 4: Cluster by geography into day-groups ────────────────────
        statusMessage = "Organising your days…"
        let itemsPerDay   = dailyItemCount(for: trip.tripPace)
        let totalDays     = trip.durationInDays
        let totalNeeded   = itemsPerDay * totalDays

        // Pick the best spread of POIs then cluster them geographically
        let selected      = selectAndCluster(from: filtered, count: totalNeeded, days: totalDays)
        progress = 0.75

        // ── Step 5: Assign days + recommended times ─────────────────────────
        statusMessage = "Building your schedule…"
        let timeSlots     = buildTimeSlots(pace: trip.tripPace, itemsPerDay: itemsPerDay)
        let tripDays      = trip.tripDays

        var items: [ItineraryItem] = []

        for (dayIndex, dayCluster) in selected.enumerated() {
            guard dayIndex < tripDays.count else { break }
            let day = tripDays[dayIndex]

            for (slotIndex, poi) in dayCluster.enumerated() {
                guard slotIndex < timeSlots.count else { break }
                let recommendedTime = combineDateAndTime(date: day, time: timeSlots[slotIndex])

                let item = ItineraryItem(
                    activityName:    poi.activityLabel,
                    venueName:       poi.name,
                    notes:           poi.notes,
                    category:        poi.category,
                    date:            day,
                    recommendedTime: recommendedTime,
                    latitude:        poi.coordinate.latitude,
                    longitude:       poi.coordinate.longitude,
                    trip:            trip
                )
                items.append(item)
            }
        }

        // ── Step 6: Save to SwiftData ───────────────────────────────────────
        statusMessage = "Saving your itinerary…"
        for item in items {
            context.insert(item)
        }
        try context.save()
        progress = 1.0
        statusMessage = "Done! Your trip is ready."
    }

    // MARK: - Step 1: Geocode
    private func geocode(city: String, country: String) async throws -> MKCoordinateRegion {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString("\(city), \(country)")

        guard let placemark = placemarks.first,
              let location  = placemark.location else {
            throw GeneratorError.geocodingFailed
        }

        // Use a ~15km radius to cover most city centres
        return MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 15_000,
            longitudinalMeters: 15_000
        )
    }

    // MARK: - Step 2: MKLocalSearch
    private func search(for term: String, in region: MKCoordinateRegion) async -> [POI] {
        let request        = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region     = region
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap { POI(from: $0) }
        } catch {
            // Silently skip failed searches — other vibes may still return results
            return []
        }
    }

    // MARK: - Step 3: Budget Filter
    /// Uses the venue category as a budget proxy.
    /// Low budget → favour food/parks/culture. High budget → allow all.
    private func filterByBudget(_ pois: [POI], level: Int) -> [POI] {
        switch level {
        case 0...3:
            // Budget-tight: skip high-end categories, favour free/cheap
            let affordable: [ItineraryItem.Category] = [.food, .sightseeing, .culture, .adventure, .rest]
            return pois.filter { affordable.contains($0.category) }
        case 4...6:
            // Moderate: everything except nightlife-heavy
            return pois
        default:
            // Budget-free: include everything
            return pois
        }
    }

    // MARK: - Step 4: Geographic Clustering
    /// Groups POIs into `days` clusters where each cluster is geographically tight.
    /// Uses a simple greedy nearest-neighbour approach per cluster seed.
    private func selectAndCluster(from pois: [POI], count: Int, days: Int) -> [[POI]] {
        var pool     = pois.shuffled()   // shuffle for variety between generations
        var clusters = [[POI]](repeating: [], count: days)
        let perDay   = count / days

        for dayIndex in 0..<days {
            guard !pool.isEmpty else { break }

            // Pick a random seed for this day
            let seed = pool.removeFirst()
            clusters[dayIndex].append(seed)

            // Greedily pick the `perDay - 1` nearest remaining POIs
            for _ in 1..<perDay {
                guard !pool.isEmpty else { break }

                let lastLocation = CLLocation(
                    latitude:  clusters[dayIndex].last!.coordinate.latitude,
                    longitude: clusters[dayIndex].last!.coordinate.longitude
                )

                // Find nearest unassigned POI
                if let nearestIndex = pool.indices.min(by: { a, b in
                    let locA = CLLocation(latitude: pool[a].coordinate.latitude,
                                         longitude: pool[a].coordinate.longitude)
                    let locB = CLLocation(latitude: pool[b].coordinate.latitude,
                                         longitude: pool[b].coordinate.longitude)
                    return lastLocation.distance(from: locA) < lastLocation.distance(from: locB)
                }) {
                    clusters[dayIndex].append(pool.remove(at: nearestIndex))
                }
            }
        }

        return clusters
    }

    // MARK: - Step 5a: Daily Item Count from Pace
    private func dailyItemCount(for pace: Int) -> Int {
        switch pace {
        case 0...3:  return 3   // Relaxed: morning, afternoon, evening
        case 4...6:  return 5   // Balanced
        case 7...8:  return 6   // Busy
        default:     return 7   // Packed
        }
    }

    // MARK: - Step 5b: Time Slots
    /// Returns an array of Date objects representing recommended times (time component only).
    /// Gaps are calculated based on pace — relaxed = longer gaps, packed = tighter.
    private func buildTimeSlots(pace: Int, itemsPerDay: Int) -> [Date] {
        // Gap in minutes between activities
        let gapMinutes: Int = {
            switch pace {
            case 0...3:  return 150   // 2.5 hrs — slow, relaxed
            case 4...6:  return 105   // 1h45 — balanced
            case 7...8:  return 90    // 1h30 — busy
            default:     return 75    // 1h15 — packed
            }
        }()

        let calendar     = Calendar.current
        var components   = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour  = 9
        components.minute = 0

        var slots: [Date] = []
        var current = calendar.date(from: components) ?? Date()

        for _ in 0..<itemsPerDay {
            slots.append(current)
            current = calendar.date(byAdding: .minute, value: gapMinutes, to: current) ?? current
        }

        return slots
    }

    // MARK: - Helpers
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let cal        = Calendar.current
        let dateComps  = cal.dateComponents([.year, .month, .day], from: date)
        let timeComps  = cal.dateComponents([.hour, .minute], from: time)
        var merged     = DateComponents()
        merged.year    = dateComps.year
        merged.month   = dateComps.month
        merged.day     = dateComps.day
        merged.hour    = timeComps.hour
        merged.minute  = timeComps.minute
        return cal.date(from: merged) ?? date
    }

    private func deduplicated(_ pois: [POI]) -> [POI] {
        var seen = Set<String>()
        return pois.filter { seen.insert($0.name.lowercased()).inserted }
    }

    // MARK: - Vibe → Search Term Mapping
    private func searchTerms(for vibes: [String]) -> [String] {
        let map: [String: [String]] = [
            "Nature":       ["park", "botanical garden", "nature reserve"],
            "History":      ["museum", "historic site", "monument"],
            "Culinary":     ["restaurant", "cafe", "food market", "bakery"],
            "Shopping":     ["shopping mall", "market", "boutique"],
            "Culture":      ["art gallery", "theatre", "cultural centre"],
            "Nightlife":    ["bar", "rooftop bar", "jazz club"],
            "Relaxation":   ["spa", "garden", "cafe"],
            "Adventure":    ["hiking trail", "outdoor activity", "sports centre"],
            "Photography":  ["viewpoint", "landmark", "scenic area"],
            "Café Hopping": ["cafe", "coffee shop", "patisserie"],
        ]

        // Flatten selected vibes into a deduplicated list of search terms
        var terms: [String] = []
        for vibe in vibes {
            if let mapped = map[vibe] {
                terms.append(contentsOf: mapped)
            }
        }
        // If no vibes selected, fall back to general tourist attractions
        if terms.isEmpty { terms = ["tourist attraction", "restaurant", "park"] }
        return Array(Set(terms))   // deduplicate
    }
}

// MARK: - POI (internal value type)
/// Lightweight intermediate struct — lives only during generation,
/// never written to SwiftData directly.
private struct POI {
    let name:       String
    let coordinate: CLLocationCoordinate2D
    let category:   ItineraryItem.Category
    let notes:      String
    let activityLabel: String   // "Visit", "Eat at", "Explore", etc.

    init?(from mapItem: MKMapItem) {
        guard let name = mapItem.name else { return nil }
        self.name       = name
        self.coordinate = mapItem.placemark.coordinate
        self.category   = Self.inferCategory(from: mapItem)
        self.notes      = Self.buildNotes(from: mapItem)
        self.activityLabel = Self.inferActivityLabel(for: self.category)
    }

    // Infer our internal category from MapKit's pointOfInterestCategory
    private static func inferCategory(from item: MKMapItem) -> ItineraryItem.Category {

        guard let poi = item.pointOfInterestCategory else {
            return .sightseeing
        }

        switch poi {

        // FOOD
        case .restaurant,
             .cafe,
             .bakery,
             .brewery,
             .foodMarket,
             .winery:
            return .food

        // SIGHTSEEING
        case .museum:
//             .landmark,
//             .nationalMonument:
            return .sightseeing

        // SHOPPING
        case .store:
//             .shoppingCenter:
            return .shopping

        // CULTURE
        case .theater,
             .movieTheater,
//             .musicVenue,
             .library:
            return .culture

        // NIGHTLIFE
        case .nightlife:
            return .nightlife

        // ADVENTURE
        case .park,
             .nationalPark,
             .beach:
            return .adventure

        // REST
        case .hotel:
            return .rest

        // TRANSPORT
        case .publicTransport,
             .airport,
             .parking:
            return .transport

        default:
            return .sightseeing
        }
    }

    // Build a short notes string from available MapKit metadata
    private static func buildNotes(from item: MKMapItem) -> String {
        var parts: [String] = []
        if let phone = item.phoneNumber { parts.append("📞 \(phone)") }
        if let url   = item.url         { parts.append("🌐 \(url.host ?? url.absoluteString)") }
        return parts.joined(separator: "  ·  ")
    }

    private static func inferActivityLabel(for category: ItineraryItem.Category) -> String {
        switch category {
        case .food:        return "Eat at"
        case .sightseeing: return "Visit"
        case .shopping:    return "Shop at"
        case .culture:     return "Explore"
        case .nightlife:   return "Night out at"
        case .adventure:   return "Adventure at"
        case .rest:        return "Relax at"
        case .transport:   return "Transit via"
        }
    }
}
