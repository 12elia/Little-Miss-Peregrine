//
//  NewTripView.swift
//  LittleMissPeregrine
//
//  Redesigned with an editorial travel-journal aesthetic.
//  Warm sand tones, bold orange accents, card-based layout.
//

import SwiftUI
import SwiftData


// MARK: - Main View
struct NewTripView: View {
    // Required
    @State private var customTripName: String = ""
    @State private var city:    String = ""
    @State private var country: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate:   Date = Date()

    // Preferences
    @State private var showPreferences  = false
    @State private var budgetLevel:   Double = 5
    @State private var tripPaceScore: Double = 5
    @State private var selectedVibes: Set<String> = []

    // Animation
    @State private var headerAppeared  = false
    @State private var cardsAppeared   = false
    
    //Itinerary Generator
    @StateObject private var generator = ItineraryGenerator()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isGenerating = false
    
    var onTripCreated: ((TripDetails) -> Void)? = nil

    // MARK: Computed helpers
    private var defaultTripNamePlaceholder: String {
        let year = Calendar.current.component(.year, from: startDate)
        if city.isEmpty && country.isEmpty { return "My Trip \(year)" }
        if country.isEmpty { return "\(city) \(year)" }
        if city.isEmpty    { return "\(country) \(year)" }
        return "\(city), \(country) \(year)"
    }

    private var computedDurationInDays: Int {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end   = cal.startOfDay(for: endDate)
        let comps = cal.dateComponents([.day], from: start, to: end)
        return max(1, (comps.day ?? 0) + 1)
    }

    private var durationLabel: String {
        let n = computedDurationInDays
        return n == 1 ? "1 day" : "\(n) days"
    }

    private var paceDescription: String {
        switch Int(tripPaceScore) {
        case 0...3: return "Slow & easy"
        case 4...7: return "Balanced"
        default:    return "Full throttle"
        }
    }

    private var budgetDescription: String {
        switch Int(budgetLevel) {
        case 0...2:  return "Cup noodles"
        case 3...4:  return "Voucher hunter"
        case 5...6:  return "Comfort mode"
        case 7...8:  return "Room service"
        default:     return "Penthouse energy"
        }
    }

    // MARK: Body
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.sand.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, 28)

                    VStack(spacing: 16) {
                        tripNameCard
                        locationCard
                        dateCard
                        preferencesCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)  // room for the sticky button
                }
            }

            // Sticky Generate Button
            generateButton
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { headerAppeared = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { cardsAppeared = true }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 4) {
            // Decorative stamp ring
            ZStack {
                Circle()
                    .strokeBorder(Color.stamp.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(width: 64, height: 64)
                Image(systemName: "airplane")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.stamp)
                    .rotationEffect(.degrees(-35))
            }
            .scaleEffect(headerAppeared ? 1 : 0.6)
            .opacity(headerAppeared ? 1 : 0)
            .padding(.top, 20)

            Text("New Trip")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(.inkDark)
                .opacity(headerAppeared ? 1 : 0)
                .offset(y: headerAppeared ? 0 : 6)

            Text("Where are we going?")
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.inkMid)
                .opacity(headerAppeared ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.45), value: headerAppeared)
    }

    // MARK: - Trip Name Card
    private var tripNameCard: some View {
        TripCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Trip Title", systemImage: "tag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.stamp)
                    .textCase(.uppercase)
                    .tracking(1)

                TextField(defaultTripNamePlaceholder, text: $customTripName)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.inkDark)
            }
        }
        .cardReveal(cardsAppeared, delay: 0.0)
    }

    // MARK: - Location Card
    private var locationCard: some View {
        TripCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Destination", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.stamp)
                    .textCase(.uppercase)
                    .tracking(1)

                HStack(spacing: 12) {
                    locationField(label: "City", placeholder: "Paris", text: $city)
                    Color.divider.frame(width: 1, height: 36)
                    locationField(label: "Country", placeholder: "France", text: $country)
                }
            }
        }
        .cardReveal(cardsAppeared, delay: 0.07)
    }

    @ViewBuilder
    private func locationField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.inkMid)
            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.inkDark)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Date Card
    private var dateCard: some View {
        TripCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Dates", systemImage: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.stamp)
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    // Duration pill
                    Text(durationLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.stamp)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.stampLight)
                        .clipShape(Capsule())
                }

                HStack(spacing: 0) {
                    datePill(label: "Departure", date: $startDate, range: nil)

                    HStack(spacing: 3) {
                        ForEach(0..<3) { _ in
                            Circle().fill(Color.divider).frame(width: 3, height: 3)
                        }
                        Image(systemName: "airplane")
                            .font(.system(size: 11))
                            .foregroundColor(.inkMid)
                        ForEach(0..<3) { _ in
                            Circle().fill(Color.divider).frame(width: 3, height: 3)
                        }
                    }
                    .padding(.horizontal, 8)

                    datePill(label: "Return", date: $endDate, range: startDate...)
                }
            }
        }
        .cardReveal(cardsAppeared, delay: 0.14)
    }

    @ViewBuilder
    private func datePill(label: String, date: Binding<Date>, range: PartialRangeFrom<Date>?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.inkMid)
            Group {
                if let range = range {
                    DatePicker("", selection: date, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: date, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(.stamp)
            .scaleEffect(0.88, anchor: .leading)
            .frame(height: 32)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Preferences Card
    private var preferencesCard: some View {
        TripCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        showPreferences.toggle()
                    }
                } label: {
                    HStack {
                        Label("Travel Preferences", systemImage: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stamp)
                            .textCase(.uppercase)
                            .tracking(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.inkMid)
                            .rotationEffect(.degrees(showPreferences ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)

                if showPreferences {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.divider.frame(height: 1).padding(.top, 14)

                        // Pace
                        preferenceSlider(
                            title: "Trip Pace",
                            value: $tripPaceScore,
                            description: paceDescription,
                            leadingIcon: "tortoise.fill",
                            leadingColor: .green,
                            trailingIcon: "hare.fill",
                            trailingColor: .stamp
                        )

                        Color.divider.frame(height: 1)

                        // Budget
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Budget")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.inkDark)
                                Spacer()
                                Text(budgetDescription)
                                    .font(.system(size: 13))
                                    .foregroundColor(.inkMid)
                            }
                            HStack(spacing: 10) {
                                Text("$")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                                Slider(value: $budgetLevel, in: 0...10, step: 1)
                                    .tint(.stamp)
                                Text("$$$")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.stamp)
                            }
                        }

                        Color.divider.frame(height: 1)

                        // Vibes
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Trip Vibes")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.inkDark)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 8) {
                                ForEach(TripDetails.vibes, id: \.self) { vibe in
                                    vibeChip(vibe)
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .cardReveal(cardsAppeared, delay: 0.21)
    }

    // Shared slider row
    @ViewBuilder
    private func preferenceSlider(
        title: String,
        value: Binding<Double>,
        description: String,
        leadingIcon: String, leadingColor: Color,
        trailingIcon: String, trailingColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.inkDark)
                Spacer()
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.inkMid)
            }
            HStack(spacing: 10) {
                Image(systemName: leadingIcon)
                    .foregroundColor(leadingColor)
                    .font(.system(size: 14))
                Slider(value: value, in: 0...10, step: 1)
                    .tint(.stamp)
                Image(systemName: trailingIcon)
                    .foregroundColor(trailingColor)
                    .font(.system(size: 14))
            }
        }
    }

    // Vibe chip
    @ViewBuilder
    private func vibeChip(_ vibe: String) -> some View {
        let selected = selectedVibes.contains(vibe)
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                if selected { selectedVibes.remove(vibe) } else { selectedVibes.insert(vibe) }
            }
        } label: {
            Text(vibe)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(selected ? Color.stamp : Color.stampLight)
                .foregroundColor(selected ? .white : .inkDark)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        selected ? Color.clear : Color.divider,
                        lineWidth: 1
                    )
                )
                .scaleEffect(selected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        VStack(spacing: 0) {
            // Fade gradient above button
            LinearGradient(
                colors: [Color.sand.opacity(0), Color.sand],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            Button {
                Task {
                    isGenerating = true
                    let trip = TripDetails(
                        city: city,
                        country: country,
                        customTripName: customTripName.isEmpty ? defaultTripNamePlaceholder : customTripName,
                        startDate: startDate,
                        endDate: endDate,
                        travelVibes: Array(selectedVibes),
                        budgetLevel: Int(budgetLevel),
                        tripPace: Int(tripPaceScore)
                    )
                    modelContext.insert(trip)
                    try? await generator.generate(for: trip, in: modelContext)
                    isGenerating = false
                    onTripCreated?(trip)
                }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                        Text(generator.statusMessage.isEmpty ? "Generating…" : generator.statusMessage)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Generate My Itinerary")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    city.isEmpty || isGenerating
                    ? Color.inkMid.opacity(0.35)
                    : Color.inkDark
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: city.isEmpty || isGenerating ? .clear : Color.inkDark.opacity(0.3),
                    radius: 12, x: 0, y: 6
                )
            }
            .disabled(city.isEmpty || isGenerating)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .background(Color.sand)
        }
        .onAppear{
            resetForm()
        }
    }
    
    private func resetForm() {
        customTripName  = ""
        city            = ""
        country         = ""
        startDate       = Date()
        endDate         = Date()
        budgetLevel     = 5.0
        tripPaceScore   = 5.0
        selectedVibes   = []
        showPreferences = false
        isGenerating    = false
    }
}

// MARK: - Card Container
struct TripCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardWhite)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.inkDark.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.divider, lineWidth: 0.5)
            )
    }
}

// MARK: - Card Reveal Modifier
private extension View {
    func cardReveal(_ appeared: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
    }
}


// MARK: - Preview
#Preview {
    NewTripView()
        .modelContainer(for: TripDetails.self, inMemory: true)
}
