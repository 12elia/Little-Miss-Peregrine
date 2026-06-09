//
//  ProofCameraView.swift
//  LittleMissPeregrine
//
//  Created by Nadia on 28/05/26.
//

import SwiftUI
import SwiftData
import AVFoundation
import CoreLocation
import ImageIO
import Combine

// MARK: - Verification Result
enum VerificationResult {
    case approved
    case warning(distance: Double)
    case rejected(distance: Double)
    case noGPS
}

// MARK: - Proof Camera View
struct ProofCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let item: ItineraryItem

    @StateObject private var locationManager = ProofLocationManager()
    @StateObject private var camera          = ProofCameraController()

    @State private var capturedImage:      UIImage?            = nil
    @State private var capturedImageData:  Data?               = nil
    @State private var verificationResult: VerificationResult? = nil
    @State private var showSuccess:        Bool                = false
    @State private var flashEnabled:       Bool                = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showSuccess {
                successOverlay
            } else if let result = verificationResult, let image = capturedImage {
                verificationScreen(image: image, result: result)
            } else if capturedImage != nil {
                verifyingScreen
            } else {
                cameraScreen
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                camera.start()
            }
        }
        .onDisappear { camera.stop() }
    }

    // MARK: - Camera Screen
    private var cameraScreen: some View {
        ZStack(alignment: .bottom) {
            // Viewfinder
            if camera.isReady {
                ProofCameraPreview(session: camera.session)
                    .ignoresSafeArea()
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
                    Button { isPresented = false } label: {
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

                // Venue chip
                HStack(spacing: 8) {
                    Image(systemName: item.categoryEnum.icon)
                        .font(.system(size: 13))
                        .foregroundColor(.stamp)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.venueName)
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text(item.activityName)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    // GPS status dot
                    HStack(spacing: 4) {
                        Circle()
                            .fill(locationManager.currentLocation != nil ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(locationManager.currentLocation != nil ? "GPS ready" : "Getting GPS…")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Bottom controls — flash | shutter | switch camera
                HStack {
                    // Flash toggle
                    Button {
                        flashEnabled.toggle()
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 22))
                            .foregroundColor(flashEnabled ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Shutter
                    Button {
                        capture()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(camera.isReady ? Color.white : Color.gray)
                                .frame(width: 72, height: 72)
                            Circle()
                                .strokeBorder(Color.white.opacity(0.4), lineWidth: 3)
                                .frame(width: 84, height: 84)
                        }
                    }
                    .disabled(!camera.isReady)

                    Spacer()

                    // Switch camera
                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Verifying Screen
    private var verifyingScreen: some View {
        ZStack {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 8)
                    .overlay(Color.black.opacity(0.5))
            }
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.4)
                Text("Verifying your location…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Verification Screen
    @ViewBuilder
    private func verificationScreen(
        image: UIImage,
        result: VerificationResult
    ) -> some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .blur(radius: 10)
                    .overlay(Color.black.opacity(0.65))

                VStack(spacing: 20) {
                    resultIcon(for: result)
                    resultMessage(for: result)
                    resultButtons(for: result)
                }
                .padding(28)
                .frame(width: geo.size.width - 48)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(radius: 20)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    // MARK: - Result Icon
    @ViewBuilder
    private func resultIcon(for result: VerificationResult) -> some View {
        switch result {
        case .approved:
            ZStack {
                Circle().fill(Color.green.opacity(0.2)).frame(width: 72, height: 72)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36)).foregroundColor(.green)
            }
        case .warning:
            ZStack {
                Circle().fill(Color.orange.opacity(0.2)).frame(width: 72, height: 72)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36)).foregroundColor(.orange)
            }
        case .rejected:
            ZStack {
                Circle().fill(Color.red.opacity(0.2)).frame(width: 72, height: 72)
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 36)).foregroundColor(.red)
            }
        case .noGPS:
            ZStack {
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 72, height: 72)
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 36)).foregroundColor(.yellow)
            }
        }
    }

    // MARK: - Result Message
    @ViewBuilder
    private func resultMessage(for result: VerificationResult) -> some View {
        switch result {
        case .approved:
            VStack(spacing: 6) {
                Text("You made it! ✦")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Location verified. \(item.venueName) — checked.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        case .warning(let distance):
            VStack(spacing: 6) {
                Text("Hmm, you're a little far…")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("Your GPS says you're \(formatDistance(distance)) from \(item.venueName). If you're really there, go ahead.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        case .rejected(let distance):
            VStack(spacing: 8) {
                Text(rejectedHeadline(distance: distance))
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(rejectedSubtitle(distance: distance))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        case .noGPS:
            VStack(spacing: 6) {
                Text("Where even are you?")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("No GPS found. Make sure Location Services is on for Camera in Settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Result Buttons
    @ViewBuilder
    private func resultButtons(for result: VerificationResult) -> some View {
        switch result {
        case .approved:
            Button { markComplete(override: false, distance: 0) } label: {
                primaryButton("Stamp it! ✦", color: .green)
            }
        case .warning(let distance):
            VStack(spacing: 10) {
                Button { markComplete(override: true, distance: distance) } label: {
                    primaryButton("I'm really here, trust me", color: .orange)
                }
                Button { retake() } label: { secondaryButton("Retake photo") }
            }
        case .rejected(let distance):
            VStack(spacing: 10) {
                Button { retake() } label: {
                    primaryButton("Go find it first", color: .stamp)
                }
                Button { markComplete(override: true, distance: distance) } label: {
                    secondaryButton("Override anyway")
                }
            }
        case .noGPS:
            VStack(spacing: 10) {
                Button { retake() } label: {
                    primaryButton("Retake", color: .stamp)
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: { secondaryButton("Open Settings") }
            }
        }
    }

    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.sand.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color.stampLight).frame(width: 100, height: 100)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.stamp)
                }
                VStack(spacing: 8) {
                    Text("Stamped! ✦")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.inkDark)
                    Text(item.venueName)
                        .font(.system(size: 16))
                        .foregroundColor(.inkMid)
                    if item.isManualOverride {
                        Text("(override logged — we see you 👀)")
                            .font(.system(size: 11))
                            .foregroundColor(.inkMid.opacity(0.6))
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isPresented = false
            }
        }
    }

    // MARK: - Button Helpers
    @ViewBuilder
    private func primaryButton(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func secondaryButton(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)  
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Color.white.opacity(0.3),
                        lineWidth: 1
                    )
            )
    }
    
    // MARK: - Core Logic
    private func capture() {
        camera.capturePhoto(flashEnabled: flashEnabled) { data in
            capturedImageData = data
            if let data, let img = UIImage(data: data) {
                capturedImage = img
                verifyPhoto()
            }
        }
    }

    private func verifyPhoto() {
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let result = buildResult()
            await MainActor.run { verificationResult = result }
        }
    }

    private func buildResult() -> VerificationResult {
        guard let photoLoc = locationManager.currentLocation else {
            return .noGPS
        }
        let distance = item.venueLocation.distance(from: photoLoc)
        switch distance {
        case ..<200:    return .approved
        case 200..<500: return .warning(distance: distance)
        default:        return .rejected(distance: distance)
        }
    }

    private func markComplete(override: Bool, distance: Double) {
        item.isCompleted      = true
        item.proofPhotoData   = capturedImageData
        item.isManualOverride = override
        item.overrideDistance = override ? distance : 0
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.3)) { showSuccess = true }
    }

    private func retake() {
        capturedImage      = nil
        capturedImageData  = nil
        verificationResult = nil
    }

    // MARK: - Rejection Messages
    private func rejectedHeadline(distance: Double) -> String {
        distance / 1000 > 10 ? "Absolutely not. 🚫"
        : distance / 1000 > 5 ? "Nice try, traveller."
        : "That's not it, chief."
    }

    private func rejectedSubtitle(distance: Double) -> String {
        let d = formatDistance(distance)
        let messages = [
            "Your GPS has filed a formal complaint. You are \(d) away from \(item.venueName). The itinerary demands your physical presence.",
            "Our highly sophisticated location bureau has detected your shenanigans. \(d) away. The venue awaits your actual arrival.",
            "Respectfully, the map disagrees with you. You're \(d) from \(item.venueName). Go touch grass — specifically, that grass.",
            "Mischief detected. You're \(d) away. The itinerary is not impressed, and frankly, neither are we.",
            "Bold submission. Wrong location. \(d) wrong, to be precise. \(item.venueName) is out there waiting for you.",
        ]
        return messages[Int(distance / 100) % messages.count]
    }

    private func formatDistance(_ metres: Double) -> String {
        metres >= 1000
            ? String(format: "%.1fkm", metres / 1000)
            : "\(Int(metres))m"
    }
}

// MARK: - Location Manager
final class ProofLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate        = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
}

// MARK: - Camera Controller
final class ProofCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session        = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue  = DispatchQueue(label: "proof.camera.queue")
    private var completion: ((Data?) -> Void)?
    private var currentPosition: AVCaptureDevice.Position = .back

    @Published var isReady       = false
    @Published var statusMessage = "Starting camera…"

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure(position: .back)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                granted ? self?.configure(position: .back)
                        : DispatchQueue.main.async { self?.statusMessage = "Camera permission denied" }
            }
        default:
            DispatchQueue.main.async { self.statusMessage = "Camera denied — check Settings" }
        }
    }

    private func configure(position: AVCaptureDevice.Position) {
        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Remove existing inputs
            self.session.inputs.forEach { self.session.removeInput($0) }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                let input  = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                DispatchQueue.main.async { self.statusMessage = "Camera unavailable" }
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)
            self.currentPosition = position

            if !self.session.outputs.contains(self.output) {
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }
            }

            self.session.commitConfiguration()

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isReady       = true
                self.statusMessage = ""
            }
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        DispatchQueue.main.async { self.isReady = false }
        configure(position: newPosition)
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    func capturePhoto(flashEnabled: Bool = false, completion: @escaping (Data?) -> Void) {
        self.completion = completion
        queue.async {
            let settings = AVCapturePhotoSettings()
            // Flash only works on back camera
            if self.currentPosition == .back {
                settings.flashMode = flashEnabled ? .on : .off
            }
            self.output.capturePhoto(with: settings, delegate: self)
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
struct ProofCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session      = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ v: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Preview
#Preview {
    let item = ItineraryItem(
        activityName: "Brunch",
        venueName: "Kozy Bosquet",
        category: .food,
        date: Date(),
        recommendedTime: Date(),
        latitude: 48.8566,
        longitude: 2.3522
    )
    return ProofCameraView(isPresented: .constant(true), item: item)
        .modelContainer(for: [TripDetails.self, ItineraryItem.self], inMemory: true)
}
