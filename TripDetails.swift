//
//  Models.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Trip Details
@Model
class TripDetails: Identifiable {

    var id:             UUID
    var city:           String
    var country:        String
    var customTripName: String
    var startDate:      Date
    var endDate:        Date
    var travelVibes:    [String]
    var budgetLevel:    Int
    var tripPace:       Int
    var rawItinerary:   String

    @Relationship(deleteRule: .cascade, inverse: \ItineraryItem.trip)
    var itineraryItems: [ItineraryItem] = []

    var durationInDays: Int {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end   = cal.startOfDay(for: endDate)
        return max(1, (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    var tripDays: [Date] {
        (0..<durationInDays).compactMap {
            Calendar.current.date(
                byAdding: .day, value: $0,
                to: Calendar.current.startOfDay(for: startDate)
            )
        }
    }

    func items(for date: Date) -> [ItineraryItem] {
        let cal = Calendar.current
        return itineraryItems
            .filter  { cal.isDate($0.date, inSameDayAs: date) }
            .sorted  { $0.recommendedTime < $1.recommendedTime }
    }

    var completionRatio: Double {
        guard !itineraryItems.isEmpty else { return 0 }
        return Double(itineraryItems.filter { $0.isCompleted }.count)
             / Double(itineraryItems.count)
    }

    static let vibes = [
        "Nature", "History", "Culinary", "Shopping",
        "Culture", "Nightlife", "Relaxation", "Adventure",
        "Photography", "Café Hopping"
    ]

    init(
        city:           String,
        country:        String,
        customTripName: String,
        startDate:      Date,
        endDate:        Date,
        travelVibes:    [String],
        budgetLevel:    Int,
        tripPace:       Int
    ) {
        self.id             = UUID()
        self.city           = city
        self.country        = country
        self.customTripName = customTripName
        self.startDate      = startDate
        self.endDate        = endDate
        self.travelVibes    = travelVibes
        self.budgetLevel    = budgetLevel
        self.tripPace       = tripPace
        self.rawItinerary   = ""
    }
}

// MARK: - Itinerary Item
@Model
class ItineraryItem: Identifiable {

    var id:              UUID
    var trip:            TripDetails?
    var activityName:    String
    var venueName:       String
    var notes:           String
    var category:        String
    var date:            Date
    var recommendedTime: Date
    var latitude:        Double
    var longitude:       Double

    // Completion
    var isCompleted:      Bool
    var isSkipped:        Bool
    var proofPhotoData:   Data?

    // Override tracking — logged when user submits despite distance warning
    var isManualOverride: Bool
    var overrideDistance: Double   // metres at time of override, 0 if not overridden

    var venueLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var categoryEnum: Category {
        Category(rawValue: category) ?? .sightseeing
    }

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: recommendedTime)
    }

    var fullTitle: String { "\(activityName) \(venueName)" }

    // MARK: - Category
    enum Category: String, CaseIterable, Codable {
        case food        = "Food & Drink"
        case sightseeing = "Sightseeing"
        case transport   = "Transport"
        case shopping    = "Shopping"
        case culture     = "Culture"
        case nightlife   = "Nightlife"
        case rest        = "Rest"
        case adventure   = "Adventure"

        var icon: String {
            switch self {
            case .food:        return "fork.knife"
            case .sightseeing: return "binoculars.fill"
            case .transport:   return "tram.fill"
            case .shopping:    return "bag.fill"
            case .culture:     return "building.columns.fill"
            case .nightlife:   return "moon.stars.fill"
            case .rest:        return "bed.double.fill"
            case .adventure:   return "figure.hiking"
            }
        }
    }

    init(
        activityName:    String,
        venueName:       String,
        notes:           String       = "",
        category:        Category     = .sightseeing,
        date:            Date,
        recommendedTime: Date,
        latitude:        Double       = 0,
        longitude:       Double       = 0,
        trip:            TripDetails? = nil
    ) {
        self.id               = UUID()
        self.trip             = trip
        self.activityName     = activityName
        self.venueName        = venueName
        self.notes            = notes
        self.category         = category.rawValue
        self.date             = date
        self.recommendedTime  = recommendedTime
        self.latitude         = latitude
        self.longitude        = longitude
        self.isCompleted      = false
        self.isSkipped        = false
        self.proofPhotoData   = nil
        self.isManualOverride = false
        self.overrideDistance = 0
    }
}
