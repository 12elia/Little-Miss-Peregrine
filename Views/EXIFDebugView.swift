//
//  EXIFDebugView.swift
//  LittleMissPeregrine
//
//  Temporary debug file — delete before submission
//

import AVFoundation
import Combine
import CoreLocation
import ImageIO
import PhotosUI
import SwiftUI

// MARK: - Location Manager

final class DebugLocationManager: NSObject, ObservableObject,
    CLLocationManagerDelegate
{
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        currentLocation = locations.last
    }
}

// MARK: - Shared EXIF Extraction

private func extractGPS(from data: Data) -> CLLocation? {
    guard
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
        let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
        let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
        let lng = gps[kCGImagePropertyGPSLongitude] as? Double
    else { return nil }

    let finalLat =
        (gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N") == "S"
        ? -lat : lat
    let finalLng =
        (gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E") == "W"
        ? -lng : lng
    return CLLocation(latitude: finalLat, longitude: finalLng)
}

// MARK: - Main Debug View

struct EXIFDebugView: View {
    // Target venue
    @State private var venueLat: String
    @State private var venueLng: String
    @State private var venueName: String

    init(latitude: Double = 0, longitude: Double = 0, venueName: String = "") {
        _venueLat = State(initialValue: latitude != 0 ? "\(latitude)" : "")
        _venueLng = State(initialValue: longitude != 0 ? "\(longitude)" : "")
        _venueName = State(initialValue: venueName)
    }

    // Photo source result
    @State private var photoLocation: CLLocation?
    @State private var photoSource: String = ""

    // Sheet controls
    @State private var showPicker = false
    @State private var showCamera = false

    private var venueLocation: CLLocation? {
        guard let lat = Double(venueLat), let lng = Double(venueLng) else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lng)
    }

    // MARK: Comparison

    private enum VerificationStatus {
        case approved, warning, rejected, noGPS
    }

    private var verificationResult:
        (status: VerificationStatus, distance: String, message: String)?
    {
        guard let venue = venueLocation else { return nil }

        guard let photo = photoLocation else {
            return (
                .noGPS, "—",
                "No GPS data in photo.\nUser may submit anyway (unverified)."
            )
        }

        let d = venue.distance(from: photo)
        let formatted =
            d >= 1000
            ? String(format: "%.2f km", d / 1000)
            : String(format: "%.0f m", d)

        switch d {
        case ..<200:
            return (.approved, formatted, "Within 200m — location verified.")
        case 200..<500:
            return (
                .warning, formatted,
                "200–500m away — soft warning.\nUser can override."
            )
        default:
            return (
                .rejected, formatted,
                "Over 500m — check-in rejected.\nOverride still available."
            )
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.sand.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    venueCard
                    photoCard
                    if venueLocation != nil {
                        resultCard
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showPicker) {
            LibraryPicker { location in
                photoLocation = location
                photoSource = location != nil ? "Library" : "Library (no GPS)"
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { location in
                photoLocation = location
                photoSource = location != nil ? "Camera" : "Camera (no GPS)"
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Location Debug")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundColor(.inkDark)
            Text("EXIF · GPS · Verification")
                .font(.system(size: 12))
                .foregroundColor(.inkMid)
        }
        .padding(.top, 56)
    }

    private var venueCard: some View {
        card(title: "Target Venue", icon: "mappin.circle.fill") {
            HStack(spacing: 10) {
                coordField(
                    "Latitude",
                    placeholder: "e.g. 48.8584",
                    text: $venueLat
                )
                coordField(
                    "Longitude",
                    placeholder: "e.g. 2.2945",
                    text: $venueLng
                )
            }
            if venueLocation == nil && (!venueLat.isEmpty || !venueLng.isEmpty)
            {
                Text("⚠️ Invalid coordinates")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
    }

    private var photoCard: some View {
        card(title: "Photo Input", icon: "camera.fill") {
            HStack(spacing: 10) {
                photoButton(label: "Camera", icon: "camera.fill", primary: true)
                {
                    showCamera = true
                }
                photoButton(
                    label: "Library",
                    icon: "photo.on.rectangle",
                    primary: false
                ) {
                    showPicker = true
                }
            }

            if let loc = photoLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(
                        "\(photoSource) · \(String(format: "%.5f", loc.coordinate.latitude)), \(String(format: "%.5f", loc.coordinate.longitude))"
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.inkDark)
                }
                .padding(.top, 4)
            } else if !photoSource.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(photoSource) · no GPS extracted")
                        .font(.system(size: 11))
                        .foregroundColor(.inkMid)
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let r = verificationResult {
            card(title: "Verification", icon: "checkmark.seal.fill") {
                HStack(alignment: .top, spacing: 12) {
                    Text(statusEmoji(r.status))
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusLabel(r.status))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(statusColor(r.status))
                        if r.distance != "—" {
                            Text("Distance: \(r.distance)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.inkMid)
                        }
                        Text(r.message)
                            .font(.system(size: 12))
                            .foregroundColor(.inkDark)
                            .lineSpacing(3)
                    }
                }
            }
        } else if photoLocation == nil && !photoSource.isEmpty {
            // No GPS case
            card(title: "Verification", icon: "checkmark.seal.fill") {
                HStack(alignment: .top, spacing: 12) {
                    Text("❓")
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No GPS Data")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.orange)
                        Text(
                            "Photo has no location embedded.\nUser may submit anyway as unverified (⚠️)."
                        )
                        .font(.system(size: 12))
                        .foregroundColor(.inkDark)
                        .lineSpacing(3)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusEmoji(_ s: VerificationStatus) -> String {
        switch s {
        case .approved: return "✅"
        case .warning: return "⚠️"
        case .rejected: return "❌"
        case .noGPS: return "❓"
        }
    }

    private func statusLabel(_ s: VerificationStatus) -> String {
        switch s {
        case .approved: return "Approved"
        case .warning: return "Warning"
        case .rejected: return "Rejected"
        case .noGPS: return "No GPS"
        }
    }

    private func statusColor(_ s: VerificationStatus) -> Color {
        switch s {
        case .approved: return .green
        case .warning: return .orange
        case .rejected: return .red
        case .noGPS: return .orange
        }
    }

    @ViewBuilder
    private func card<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.stamp)
                .textCase(.uppercase)
                .tracking(1.2)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func coordField(
        _ label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.inkMid)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.inkDark)
                .padding(8)
                .background(Color.sand)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func photoButton(
        label: String,
        icon: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(primary ? .white : .stamp)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(primary ? Color.inkDark : Color.stampLight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        primary ? .clear : Color.stamp.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library Picker

struct LibraryPicker: UIViewControllerRepresentable {
    let onResult: (CLLocation?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context)
    {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ p: LibraryPicker) { parent = p }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            parent.dismiss()
            guard let result = results.first else { return }

            result.itemProvider.loadFileRepresentation(
                forTypeIdentifier: "public.image"
            ) { url, _ in
                let location: CLLocation? = {
                    guard let url = url,
                        let data = try? Data(contentsOf: url)
                    else { return nil }
                    return extractGPS(from: data)
                }()
                DispatchQueue.main.async { self.parent.onResult(location) }
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: View {
    @Binding var isPresented: Bool
    let onResult: (CLLocation?) -> Void

    @StateObject private var locationManager = DebugLocationManager()
    @StateObject private var camera = CameraController()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if camera.isReady {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text(camera.statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // GPS status
                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            locationManager.currentLocation != nil
                                ? Color.green : Color.orange
                        )
                        .frame(width: 7, height: 7)
                    Text(
                        locationManager.currentLocation != nil
                            ? "GPS ready · ±\(Int(locationManager.currentLocation!.horizontalAccuracy))m"
                            : "Waiting for GPS…"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.bottom, 14)

                // Shutter
                Button {
                    camera.capturePhoto { data in
                        guard data != nil else {
                            onResult(nil)
                            isPresented = false
                            return
                        }
                        onResult(locationManager.currentLocation)
                        isPresented = false
                    }
                } label: {
                    ZStack {
                        Circle().fill(camera.isReady ? Color.white : Color.gray)
                            .frame(width: 68, height: 68)
                        Circle().strokeBorder(
                            Color.white.opacity(0.4),
                            lineWidth: 3
                        )
                        .frame(width: 80, height: 80)
                    }
                }
                .disabled(!camera.isReady)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                camera.start()
            }
        }
        .onDisappear { camera.stop() }
    }
}

// MARK: - Camera Controller

final class CameraController: NSObject, ObservableObject,
    AVCapturePhotoCaptureDelegate
{
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "debug.camera")
    private var completion: ((Data?) -> Void)?

    @Published var isReady = false
    @Published var statusMessage = "Starting camera…"

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                granted
                    ? self?.configure()
                    : DispatchQueue.main.async {
                        self?.statusMessage = "Camera permission denied"
                    }
            }
        default:
            DispatchQueue.main.async {
                self.statusMessage = "Camera denied — check Settings"
            }
        }
    }

    private func configure() {
        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .back
                ),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                DispatchQueue.main.async {
                    self.statusMessage = "Camera unavailable"
                }
                return
            }

            self.session.addInput(input)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isReady = true
                self.statusMessage = ""
            }
        }
    }

    func stop() { queue.async { self.session.stopRunning() } }

    func capturePhoto(completion: @escaping (Data?) -> Void) {
        self.completion = completion
        queue.async {
            self.output.capturePhoto(
                with: AVCapturePhotoSettings(),
                delegate: self
            )
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async {
            self.completion?(data)
            self.completion = nil
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: PreviewView, context: Context) {}
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

#Preview { EXIFDebugView() }
