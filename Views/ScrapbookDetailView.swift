//
//  ScrapbookDetailView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import SwiftUI
import SwiftData

// MARK: - Scrapbook Detail View
struct ScrapbookDetailView: View {
    let trip: TripDetails
    @State private var appeared = false

    private var completedItems: [ItineraryItem] {
        trip.itineraryItems
            .filter { $0.isCompleted }
            .sorted { $0.recommendedTime < $1.recommendedTime }
    }

    private var dateRangeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy"
        return "\(fmt.string(from: trip.startDate)) – \(fmt.string(from: trip.endDate))"
    }

    private var totalDays: Int { trip.durationInDays }

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    scrapbookCover
                    tripStats
                    Divider()
                        .background(Color.divider)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)

                    if completedItems.isEmpty {
                        noPhotosState
                    } else {
                        scrapbookPages
                    }

                    // Footer stamp
                    footerStamp
                        .padding(.top, 32)
                        .padding(.bottom, 60)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Cover
    private var scrapbookCover: some View {
        ZStack(alignment: .bottom) {
            // Background — use first proof photo or gradient placeholder
            if let firstPhoto = completedItems.first?.proofPhotoData,
               let img = UIImage(data: firstPhoto) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.inkDark.opacity(0.7)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.stampLight, Color.sand],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Canvas { ctx, size in
                        let sp: CGFloat = 16
                        var x: CGFloat = 0
                        while x < size.width {
                            var p = Path()
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            ctx.stroke(p, with: .color(Color.stamp.opacity(0.06)), lineWidth: 0.5)
                            x += sp
                        }
                        var y: CGFloat = 0
                        while y < size.height {
                            var p = Path()
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            ctx.stroke(p, with: .color(Color.stamp.opacity(0.06)), lineWidth: 0.5)
                            y += sp
                        }
                    }
                    VStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .font(.system(size: 44))
                            .foregroundColor(.stamp.opacity(0.25))
                            .rotationEffect(.degrees(-35))
                        Text("no cover photo yet")
                            .font(.system(size: 11))
                            .foregroundColor(.stamp.opacity(0.4))
                            .tracking(1)
                            .textCase(.uppercase)
                    }
                }
                .frame(height: 280)
            }

            // Title overlay
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.customTripName)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(trip.city), \(trip.country)")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text(dateRangeString)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .frame(height: 280)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.5), value: appeared)
    }

    // MARK: - Trip Stats
    private var tripStats: some View {
        HStack(spacing: 0) {
            statCell(value: "\(totalDays)", label: "Days")
            statDivider
            statCell(value: "\(trip.itineraryItems.count)", label: "Stops")
            statDivider
            statCell(value: "\(completedItems.count)", label: "Stamped")
            statDivider
            statCell(
                value: "\(Int(trip.completionRatio * 100))%",
                label: "Complete"
            )
        }
        .padding(.vertical, 16)
        .background(Color.cardWhite)
        .overlay(Rectangle().fill(Color.divider).frame(height: 0.5), alignment: .bottom)
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(.inkDark)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.inkMid)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(width: 1, height: 32)
    }

    // MARK: - No Photos State
    private var noPhotosState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 36))
                .foregroundColor(.stamp.opacity(0.35))
            Text("No stamps yet")
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(.inkDark)
            Text("Complete stops on your trip to\nbuild your scrapbook.")
                .font(.system(size: 13))
                .foregroundColor(.inkMid)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.top, 48)
    }

    // MARK: - Scrapbook Pages
    private var scrapbookPages: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section label
            Text("Your Stamps")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.stamp)
                .textCase(.uppercase)
                .tracking(2)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Group by day
            ForEach(trip.tripDays, id: \.self) { day in
                let dayItems = completedItems.filter {
                    Calendar.current.isDate($0.date, inSameDayAs: day)
                }
                if !dayItems.isEmpty {
                    ScrapbookDaySection(day: day, items: dayItems, appeared: appeared)
                }
            }
        }
    }

    // MARK: - Footer Stamp
    private var footerStamp: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(Color.stamp.opacity(0.2),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 64, height: 64)
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.stamp.opacity(0.5))
                    Text("verified")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.stamp.opacity(0.5))
                        .tracking(1.5)
                        .textCase(.uppercase)
                }
            }
            Text("little miss peregrine")
                .font(.system(size: 9))
                .foregroundColor(.inkMid.opacity(0.4))
                .tracking(2)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Scrapbook Day Section
struct ScrapbookDaySection: View {
    let day:      Date
    let items:    [ItineraryItem]
    let appeared: Bool

    private var dayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day label
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.stamp.opacity(0.3))
                    .frame(width: 3, height: 16)
                    .clipShape(Capsule())
                Text(dayString)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.inkDark)
            }
            .padding(.horizontal, 20)

            // Cards — alternate layout for visual interest
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                if i % 3 == 0 && items.count > 1 {
                    // Wide featured card
                    ScrapbookFeatureCard(item: item)
                        .padding(.horizontal, 20)
                } else {
                    // Standard card
                    ScrapbookStopCard(item: item)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Scrapbook Feature Card (large)
struct ScrapbookFeatureCard: View {
    let item: ItineraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo or placeholder
            ZStack(alignment: .bottomLeading) {
                if let data = item.proofPhotoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.clear, Color.inkDark.opacity(0.5)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                } else {
                    photoPlaceholder(height: 200)
                }

                // Venue name on photo
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.venueName)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Text(item.formattedTime)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(14)
            }
            .frame(height: 200)

            // Bottom strip
            HStack(spacing: 8) {
                Image(systemName: item.categoryEnum.icon)
                    .font(.system(size: 12))
                    .foregroundColor(.stamp)
                Text(item.activityName)
                    .font(.system(size: 12))
                    .foregroundColor(.inkMid)
                Spacer()
                if item.isManualOverride {
                    Text("override")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.inkMid.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            Capsule().strokeBorder(Color.divider, lineWidth: 0.5)
                        )
                }
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.stamp)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.inkDark.opacity(0.06), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
    }
}

// MARK: - Scrapbook Stop Card (standard)
struct ScrapbookStopCard: View {
    let item: ItineraryItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let data = item.proofPhotoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipped()
                } else {
                    photoPlaceholder(height: 72)
                        .frame(width: 72, height: 72)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.venueName)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.inkDark)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: item.categoryEnum.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.stamp)
                    Text(item.categoryEnum.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.inkMid)
                }
                Text(item.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.inkMid.opacity(0.6))
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.stamp)
                .font(.system(size: 16))
        }
        .padding(12)
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.inkDark.opacity(0.04), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
    }
}

// MARK: - Shared Photo Placeholder
@ViewBuilder
private func photoPlaceholder(height: CGFloat) -> some View {
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
        Image(systemName: "camera.fill")
            .font(.system(size: height * 0.22))
            .foregroundColor(.stamp.opacity(0.3))
    }
    .frame(height: height)
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ScrapbookDetailView(trip: DummyData.pastTrips[0])
    }
    .modelContainer(for: [TripDetails.self, ItineraryItem.self], inMemory: true)
}
