//
//  TripDetailView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI


// MARK: - Display Mode
enum DetailDisplayMode: String, CaseIterable {
    case day  = "Day View"
    case list = "Full List"
}

// MARK: - Trip Detail View
struct TripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: TripDetails

    @State private var displayMode: DetailDisplayMode = .day
    @State private var selectedDay:  Date
    @State private var showCamera    = false
//    @State private var activeItem:   ItineraryItem? = nil
    @State private var activeItem: ItineraryItem?

    init(trip: TripDetails) {
        self.trip = trip
        let today    = Calendar.current.startOfDay(for: Date())
        let tripDays = trip.tripDays
        _selectedDay = State(
            initialValue: tripDays.first(where: {
                Calendar.current.isDate($0, inSameDayAs: today)
            }) ?? tripDays.first ?? today
        )
    }

    private var dayItems: [ItineraryItem] { trip.items(for: selectedDay) }

    private var overallProgress: Double { trip.completionRatio }

    private var dayProgress: Double {
        let items = dayItems
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.isCompleted }.count) / Double(items.count)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.sand.ignoresSafeArea()

            VStack(spacing: 0) {
                tripHeader
                modeToggle
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                if displayMode == .day {
                    DayView(
                        trip:        trip,
                        selectedDay: $selectedDay,
                        dayItems:    dayItems,
                        dayProgress: dayProgress,
                        onSwipeRight: { item in
                            activeItem = item
                        },
                        onSwipeLeft: { item in
                            withAnimation(.spring(response: 0.3)) {
                                item.isSkipped = true
                            }
                            try? modelContext.save()
                        },
                        onDelete: { item in
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                    )
                } else {
                    ListView(
                        trip:     trip,
                        onDelete: { item in
                            modelContext.delete(item)
                            try? modelContext.save()
                        },
                        onSwipeRight: { item in
                            activeItem = item
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showCamera = true
                            }
                        }
                    )
                }
            }

            if displayMode == .list {
                floatingAddButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(trip.customTripName)
//        .navigationDestination(item: $activeItem) { item in
//            ProofCameraView(
//                isPresented: .constant(true),
//                item: item
//            )
//        }
        .fullScreenCover(item: $activeItem) { item in
            ProofCameraView(
                isPresented: Binding(
                    get: { activeItem != nil },
                    set: { if !$0 { activeItem = nil } }
                ),
                item: item
            )
        }
    }

    // MARK: - Trip Header
    private var tripHeader: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.stamp)
                            .font(.system(size: 13))
                        Text("\(trip.city), \(trip.country)")
                            .font(.system(size: 13))
                            .foregroundColor(.inkMid)
                    }
                    Text("\(dateRangeString) · \(trip.durationInDays) days")
                        .font(.system(size: 12))
                        .foregroundColor(.inkMid)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.divider, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: overallProgress)
                        .stroke(Color.stamp, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(overallProgress * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.inkDark)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.divider)
                    Rectangle()
                        .fill(Color.stamp)
                        .frame(width: geo.size.width * overallProgress)
                        .animation(.easeInOut(duration: 0.5), value: overallProgress)
                }
            }
            .frame(height: 2)
        }
        .padding(.bottom, 4)
        .background(Color.cardWhite)
        .overlay(Rectangle().fill(Color.divider).frame(height: 0.5), alignment: .bottom)
    }

    // MARK: - Mode Toggle
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(DetailDisplayMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        displayMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: displayMode == mode ? .semibold : .regular))
                        .foregroundColor(displayMode == mode ? .white : .inkMid)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(displayMode == mode ? Color.stamp : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.cardWhite)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.divider, lineWidth: 0.5))
    }

    // MARK: - Floating Add Button
    private var floatingAddButton: some View {
        NavigationLink(destination: AddItemView(trip: trip)) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                Text("Add Stop")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.stamp)
            .clipShape(Capsule())
            .shadow(color: Color.stamp.opacity(0.4), radius: 12, x: 0, y: 5)
        }
        .padding(.bottom, 36)
    }

    private var dateRangeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return "\(fmt.string(from: trip.startDate)) – \(fmt.string(from: trip.endDate))"
    }
}

// MARK: - Day View
struct DayView: View {
    let trip:         TripDetails
    @Binding var selectedDay: Date
    let dayItems:     [ItineraryItem]
    let dayProgress:  Double
    let onSwipeRight: (ItineraryItem) -> Void
    let onSwipeLeft:  (ItineraryItem) -> Void
    let onDelete:     (ItineraryItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                dayStrip.padding(.bottom, 12)
                dayProgressBar.padding(.horizontal, 20).padding(.bottom, 14)
                MiniMapView(items: dayItems)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                if dayItems.isEmpty { emptyDayState } else { timelineList }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: Day Strip
    private var dayStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trip.tripDays, id: \.self) { day in
                        let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                        let isToday    = Calendar.current.isDateInToday(day)
                        let items      = trip.items(for: day)
                        let done       = items.filter { $0.isCompleted }.count

                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedDay = day }
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayLabel(day))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : .inkMid)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text(dayNumber(day))
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(isSelected ? .white : .inkDark)
                                HStack(spacing: 2) {
                                    ForEach(0..<max(1, min(items.count, 5)), id: \.self) { i in
                                        Circle()
                                            .fill(i < done
                                                  ? (isSelected ? Color.white : Color.stamp)
                                                  : (isSelected ? Color.white.opacity(0.3) : Color.divider))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                if isToday && !isSelected {
                                    Circle().fill(Color.stamp).frame(width: 4, height: 4)
                                } else {
                                    Circle().fill(Color.clear).frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 52, height: 74)
                            .background(isSelected ? Color.stamp : Color.cardWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(isSelected ? Color.clear : Color.divider, lineWidth: 0.5)
                            )
                            .shadow(color: isSelected ? Color.stamp.opacity(0.3) : .clear, radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .onAppear { proxy.scrollTo(selectedDay, anchor: .center) }
        }
    }

    // MARK: Day Progress Bar
    private var dayProgressBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                let done = dayItems.filter { $0.isCompleted }.count
                Text("\(done) of \(dayItems.count) done today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.inkMid)
                Spacer()
                Text("\(Int(dayProgress * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.stamp)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.divider).frame(height: 6)
                    Capsule().fill(Color.stamp)
                        .frame(width: geo.size.width * dayProgress, height: 6)
                        .animation(.easeInOut(duration: 0.4), value: dayProgress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: Timeline
    private var timelineList: some View {
        VStack(spacing: 0) {
            ForEach(Array(dayItems.enumerated()), id: \.element.id) { i, item in
                TimelineRow(
                    item:         item,
                    isLast:       i == dayItems.count - 1,
                    onSwipeRight: { onSwipeRight(item) },
                    onSwipeLeft:  { onSwipeLeft(item) }
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyDayState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.stamp.opacity(0.4))
            Text("No stops for this day")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(.inkMid)
            Text("Switch to Full List to add one")
                .font(.system(size: 12))
                .foregroundColor(.inkMid.opacity(0.7))
        }
        .padding(.top, 48)
    }

    private func dayLabel(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"; return fmt.string(from: date)
    }
    private func dayNumber(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "d"; return fmt.string(from: date)
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let item:         ItineraryItem
    let isLast:       Bool
    let onSwipeRight: () -> Void
    let onSwipeLeft:  () -> Void

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 80

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Spine
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(item.isCompleted ? Color.stamp : item.isSkipped ? Color.divider : Color.cardWhite)
                        .frame(width: 20, height: 20)
                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                    } else if item.isSkipped {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold)).foregroundColor(.inkMid)
                    } else {
                        Circle().strokeBorder(Color.stamp, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
                if !isLast {
                    Rectangle().fill(Color.divider).frame(width: 1.5).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)
            .padding(.top, 2)

            // Swipeable card
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.green.opacity(0.12))
                    .overlay(HStack {
                        Image(systemName: "camera.fill").foregroundColor(.green)
                            .font(.system(size: 18)).padding(.leading, 20)
                        Spacer()
                    })
                    .opacity(offset > 0 ? Double(min(offset / threshold, 1)) : 0)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(0.10))
                    .overlay(HStack {
                        Spacer()
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red.opacity(0.7))
                            .font(.system(size: 18)).padding(.trailing, 20)
                    })
                    .opacity(offset < 0 ? Double(min(-offset / threshold, 1)) : 0)

                itemCard
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                guard !item.isCompleted && !item.isSkipped else { return }
                                offset = val.translation.width * 0.7
                            }
                            .onEnded { val in
                                if val.translation.width > threshold {
                                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                                    onSwipeRight()
                                } else if val.translation.width < -threshold {
                                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                                    onSwipeLeft()
                                } else {
                                    withAnimation(.spring(response: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
            .padding(.bottom, isLast ? 0 : 12)
        }
        .padding(.top, 4)
    }

    private var itemCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.isCompleted ? Color.stamp : item.isSkipped ? Color.divider : Color.stampLight)
                    .frame(width: 40, height: 40)
                Image(systemName: item.categoryEnum.icon)
                    .font(.system(size: 15))
                    .foregroundColor(item.isCompleted ? .white : item.isSkipped ? .inkMid : .stamp)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.formattedTime)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.inkMid).textCase(.uppercase).tracking(0.5)
                Text(item.venueName)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(item.isSkipped ? .inkMid : .inkDark)
                    .strikethrough(item.isSkipped)
                Text(item.activityName)
                    .font(.system(size: 12)).foregroundColor(.inkMid)
            }
            Spacer()
            Group {
                if item.isCompleted {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.stamp)
                } else if item.isSkipped {
                    Image(systemName: "xmark.circle").foregroundColor(.inkMid.opacity(0.5))
                } else {
                    Image(systemName: "chevron.right").foregroundColor(.inkMid.opacity(0.3))
                        .font(.system(size: 11))
                }
            }
            .font(.system(size: 18))
        }
        .padding(12)
        .background(item.isSkipped ? Color.cardWhite.opacity(0.5) : Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    item.isCompleted ? Color.stamp.opacity(0.35) : Color.divider,
                    lineWidth: item.isCompleted ? 1.5 : 0.5
                )
        )
        .opacity(item.isSkipped ? 0.55 : 1)
    }
}

// MARK: - Mini Map
struct MiniMapView: View {
    let items: [ItineraryItem]
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 3000,
        longitudinalMeters: 3000
    )

    private var validItems: [ItineraryItem] {
        items.filter { $0.latitude != 0 && $0.longitude != 0 }
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: validItems) { item in
            MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude)
            ) {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(item.isCompleted ? Color.stamp : Color.cardWhite)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.inkDark.opacity(0.2), radius: 4)
                        Image(systemName: item.categoryEnum.icon)
                            .font(.system(size: 11))
                            .foregroundColor(item.isCompleted ? .white : .stamp)
                    }
                    PinTriangle()
                        .fill(item.isCompleted ? Color.stamp : Color.cardWhite)
                        .frame(width: 8, height: 5)
                }
            }
        }
        .onAppear { fitRegion() }
        .onChange(of: items.count) { _ in fitRegion() }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
    }

    private func fitRegion() {
        guard !validItems.isEmpty else { return }
        let lats = validItems.map { $0.latitude }
        let lngs = validItems.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.01, (lats.max()! - lats.min()!) * 1.6),
            longitudeDelta: max(0.01, (lngs.max()! - lngs.min()!) * 1.6)
        )
        withAnimation { region = MKCoordinateRegion(center: center, span: span) }
    }
}

struct PinTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Full List View
struct ListView: View {
    let trip:         TripDetails
    let onDelete:     (ItineraryItem) -> Void
    let onSwipeRight: (ItineraryItem) -> Void

    private var groupedItems: [(Date, [ItineraryItem])] {
        trip.tripDays.map { ($0, trip.items(for: $0)) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groupedItems, id: \.0) { day, items in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(dayHeaderString(day))
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundColor(.inkDark)
                            Spacer()
                            Text("\(items.filter { $0.isCompleted }.count)/\(items.count)")
                                .font(.system(size: 11)).foregroundColor(.inkMid)
                        }
                        .padding(.horizontal, 20)

                        if items.isEmpty {
                            Text("No stops yet")
                                .font(.system(size: 12))
                                .foregroundColor(.inkMid.opacity(0.5))
                                .padding(.horizontal, 20)
                        } else {
                            ForEach(items) { item in
                                ListItemRow(item: item, onDelete: { onDelete(item) })
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func dayHeaderString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, d MMMM"; return fmt.string(from: date)
    }
}

// MARK: - List Item Row
struct ListItemRow: View {
    let item:     ItineraryItem
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.isCompleted ? Color.stamp : Color.stampLight)
                    .frame(width: 38, height: 38)
                Image(systemName: item.categoryEnum.icon)
                    .font(.system(size: 14))
                    .foregroundColor(item.isCompleted ? .white : .stamp)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.venueName)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(.inkDark)
                    .strikethrough(item.isCompleted || item.isSkipped)
                HStack(spacing: 6) {
                    Text(item.formattedTime).font(.system(size: 11)).foregroundColor(.inkMid)
                    Text("·").foregroundColor(.divider)
                    Text(item.categoryEnum.rawValue).font(.system(size: 11)).foregroundColor(.inkMid)
                }
            }
            Spacer()
            if item.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.stamp).font(.system(size: 16))
            }
        }
        .padding(12)
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Item View
struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    let trip: TripDetails

    @State private var activityName      = ""
    @State private var searchText        = ""
    @State private var selectedVenue:    MKMapItem? = nil
    @State private var searchResults:    [MKMapItem] = []
    @State private var selectedDay:      Date
    @State private var selectedTime      = Date()
    @State private var selectedCategory: ItineraryItem.Category = .sightseeing
    @State private var searchTask:       Task<Void, Never>? = nil

    init(trip: TripDetails) {
        self.trip = trip
        _selectedDay = State(initialValue: trip.tripDays.first ?? Date())
    }

    private var canSave: Bool {
        !activityName.trimmingCharacters(in: .whitespaces).isEmpty && selectedVenue != nil
    }

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        fieldCard(label: "Activity", icon: "text.cursor") {
                            TextField("e.g. Brunch, Visit, Explore", text: $activityName)
                                .font(.system(size: 15)).foregroundColor(.inkDark)
                        }

                        fieldCard(label: "Location", icon: "magnifyingglass") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Search for a real place…", text: $searchText)
                                    .font(.system(size: 15)).foregroundColor(.inkDark)
                                    .onChange(of: searchText) { query in
                                        selectedVenue = nil
                                        searchTask?.cancel()
                                        guard query.count > 2 else { searchResults = []; return }
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 400_000_000)
                                            guard !Task.isCancelled else { return }
                                            await performSearch(query: query)
                                        }
                                    }

                                if let venue = selectedVenue {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green).font(.system(size: 13))
                                        Text(venue.name ?? "")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.inkDark).lineLimit(1)
                                        Spacer()
                                        Button {
                                            selectedVenue = nil; searchText = ""; searchResults = []
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.inkMid.opacity(0.5))
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.green.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                if !searchResults.isEmpty && selectedVenue == nil {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults.indices, id: \.self) { i in
                                            let mapItem = searchResults[i]
                                            Button {
                                                selectedVenue = mapItem
                                                searchText    = mapItem.name ?? ""
                                                searchResults = []
                                                if let cat = inferCategory(from: mapItem) {
                                                    selectedCategory = cat
                                                }
                                            } label: {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "mappin.circle.fill")
                                                        .foregroundColor(.stamp).font(.system(size: 14))
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(mapItem.name ?? "Unknown")
                                                            .font(.system(size: 13, weight: .medium))
                                                            .foregroundColor(.inkDark).lineLimit(1)
                                                        Text(mapItem.placemark.title ?? "")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.inkMid).lineLimit(1)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12).padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            if i < searchResults.count - 1 {
                                                Divider().padding(.leading, 36)
                                            }
                                        }
                                    }
                                    .background(Color.cardWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.divider, lineWidth: 0.5))
                                    .shadow(color: Color.inkDark.opacity(0.06), radius: 8, x: 0, y: 3)
                                }
                            }
                        }

                        fieldCard(label: "Day", icon: "calendar") {
                            Picker("Day", selection: $selectedDay) {
                                ForEach(trip.tripDays, id: \.self) { day in
                                    Text(dayPickerLabel(day)).tag(day)
                                }
                            }
                            .pickerStyle(.menu).tint(.stamp)
                        }

                        fieldCard(label: "Recommended Time", icon: "clock") {
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .labelsHidden().tint(.stamp)
                        }

                        fieldCard(label: "Category", icon: "tag") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ItineraryItem.Category.allCases, id: \.self) { cat in
                                        Button { selectedCategory = cat } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: cat.icon).font(.system(size: 11))
                                                Text(cat.rawValue).font(.system(size: 11, weight: .medium))
                                            }
                                            .foregroundColor(selectedCategory == cat ? .white : .inkMid)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(selectedCategory == cat ? Color.stamp : Color.stampLight)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 40)
                }
                saveButton
            }
        }
        .navigationTitle("New Stop")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }

    private var navBar: some View {
        Rectangle()
            .fill(Color.cardWhite)
            .frame(height: 0.5)
            .overlay(Rectangle().fill(Color.divider).frame(height: 0.5), alignment: .bottom)
    }

    @ViewBuilder
    private func fieldCard<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.stamp).textCase(.uppercase).tracking(1)
            content()
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.divider, lineWidth: 0.5))
    }

    private var saveButton: some View {
        Button { saveItem() } label: {
            Text("Add to Itinerary")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canSave ? Color.stamp : Color.inkMid.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSave)
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(Color.sand)
    }

    @MainActor
    private func performSearch(query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = Array(response.mapItems.prefix(5))
        } catch { searchResults = [] }
    }

    private func saveItem() {
        guard let venue = selectedVenue else { return }
        let coord = venue.placemark.coordinate
        let item  = ItineraryItem(
            activityName:    activityName.trimmingCharacters(in: .whitespaces),
            venueName:       venue.name ?? searchText,
            notes:           "",
            category:        selectedCategory,
            date:            selectedDay,
            recommendedTime: selectedTime,
            latitude:        coord.latitude,
            longitude:       coord.longitude,
            trip:            trip
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }

    private func dayPickerLabel(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE, d MMM"; return fmt.string(from: date)
    }

    private func inferCategory(from item: MKMapItem) -> ItineraryItem.Category? {
        guard let cat = item.pointOfInterestCategory else { return nil }
        switch cat {
        case .restaurant, .cafe, .bakery, .brewery, .foodMarket: return .food
        case .museum/*, .landmark, .nationalMonument*/:               return .sightseeing
        case .store:                                               return .shopping
        case .theater, .movieTheater /*.musicVenue*/:                return .culture
        case .nightlife:                                           return .nightlife
        case .park, .nationalPark, .beach:                         return .adventure
        case .hotel/*, .spa*/:                                         return .rest
        default:                                                   return nil
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TripDetailView(trip: {
            let t = TripDetails(
                city: "Paris", country: "France",
                customTripName: "Paris 2026",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                travelVibes: ["Culinary", "History"],
                budgetLevel: 5, tripPace: 5
            )
            return t
        }())
    }
    .modelContainer(for: [TripDetails.self, ItineraryItem.self], inMemory: true)
}
