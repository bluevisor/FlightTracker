import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @FocusState private var focusedFlightID: String?
    @State private var showingFlightDetail = false
    @State private var zoomLevel: ZoomLevel = .medium
    @State private var showZoomHUD = false

    enum ZoomLevel {
        case close   // 1° span
        case medium  // 5° span
        case wide    // 20° span

        var span: Double {
            switch self {
            case .close: return 1.0
            case .medium: return 5.0
            case .wide: return 20.0
            }
        }

        var label: String {
            switch self {
            case .close: return "Close 🔍"
            case .medium: return "Medium 🗺️"
            case .wide: return "Wide 🌍"
            }
        }
    }

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: $viewModel.cameraPosition, interactionModes: []) {
                ForEach(viewModel.flights) { flight in
                    Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                        FlightAnnotationView(
                            flight: flight,
                            isFocused: focusedFlightID == flight.id,
                            isSelected: viewModel.selectedFlight?.id == flight.id
                        )
                        .focusable()
                        .focused($focusedFlightID, equals: flight.id)
                        .onTapGesture {
                            selectFlight(flight)
                        }
                    }
                }

                // Selected flight path
                if !viewModel.selectedFlightPath.isEmpty {
                    MapPolyline(coordinates: viewModel.selectedFlightPath)
                        .stroke(Gradient(colors: [.clear, .yellow]), lineWidth: 4)
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea()

            // Zoom HUD (appears temporarily)
            if showZoomHUD {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                        Text("Zoom: \(zoomLevel.label)")
                            .font(.headline)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                    .padding(.top, 60)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Flight info card (when flight selected)
            if showingFlightDetail, let flight = viewModel.selectedFlight {
                VStack {
                    Spacer()

                    FlightInfoCard(flight: flight, viewModel: viewModel, showingDetail: $showingFlightDetail)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 200) // Above toolbar
                }
            }

            // Bottom toolbar (always visible)
            VStack {
                Spacer()
                BottomToolbar(
                    viewModel: viewModel,
                    onReset: resetMapView,
                    onInfo: toggleFlightInfo,
                    onSort: { /* TODO */ },
                    onFilter: { /* TODO */ }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            print("🚀 ContentView appeared")
            setupInitialMapPosition()
        }
        .onPlayPauseCommand {
            cycleZoomLevel()
        }
        .onExitCommand {
            if showingFlightDetail {
                withAnimation {
                    showingFlightDetail = false
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func selectFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            viewModel.selectFlight(flight)
            showingFlightDetail = true
        }
    }

    private func setupInitialMapPosition() {
        let center = viewModel.userLocation ?? CLLocationCoordinate2D(
            latitude: AppConfig.defaultLatitude,
            longitude: AppConfig.defaultLongitude
        )
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: zoomLevel.span, longitudeDelta: zoomLevel.span)
        )
        viewModel.cameraPosition = .region(region)
        viewModel.updateViewRegion(region)
    }

    private func resetMapView() {
        setupInitialMapPosition()
    }

    private func toggleFlightInfo() {
        if viewModel.selectedFlight != nil {
            withAnimation {
                showingFlightDetail.toggle()
            }
        }
    }

    private func cycleZoomLevel() {
        withAnimation(.easeInOut(duration: 0.6)) {
            switch zoomLevel {
            case .medium:
                zoomLevel = .close
            case .close:
                zoomLevel = .wide
            case .wide:
                zoomLevel = .medium
            }

            // Update map region
            guard let region = viewModel.currentViewRegion else { return }
            let newSpan = MKCoordinateSpan(
                latitudeDelta: zoomLevel.span,
                longitudeDelta: zoomLevel.span
            )
            let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
            viewModel.cameraPosition = .region(newRegion)
        }

        // Show HUD
        withAnimation {
            showZoomHUD = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation {
                showZoomHUD = false
            }
        }
    }
}

// MARK: - Supporting Views

struct FlightAnnotationView: View {
    let flight: Flight
    let isFocused: Bool
    let isSelected: Bool

    @State private var isPulsing = false

    var iconSize: CGFloat {
        if isSelected { return 64 }
        if isFocused { return 56 }
        return 32
    }

    var iconColor: Color {
        (isFocused || isSelected) ? .yellow : .white
    }

    var body: some View {
        VStack(spacing: 8) {
            // Label (only when focused or selected)
            if isFocused || isSelected {
                VStack(spacing: 2) {
                    Text(flight.formattedCallsign)
                        .font(.system(size: 28, weight: .bold))
                    Text(flight.formattedAltitude)
                        .font(.system(size: 22, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }

            // Airplane icon
            Image(systemName: "airplane")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .rotationEffect(.degrees(flight.track ?? 0))
                .foregroundStyle(iconColor)
                .shadow(
                    color: isFocused ? .yellow.opacity(0.8) : .black,
                    radius: isFocused ? 20 : 4
                )
                .scaleEffect(isPulsing && isFocused ? 1.1 : 1.0)
        }
        .onChange(of: isFocused) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation {
                    isPulsing = false
                }
            }
        }
        .accessibilityLabel("""
            \(flight.formattedCallsign), \
            \(flight.originCountry), \
            altitude \(flight.formattedAltitude), \
            speed \(flight.formattedGroundSpeed), \
            heading \(Int(flight.track ?? 0)) degrees
        """)
        .accessibilityHint("Double-tap to view flight details")
    }
}

struct BottomToolbar: View {
    @ObservedObject var viewModel: FlightViewModel
    let onReset: () -> Void
    let onInfo: () -> Void
    let onSort: () -> Void
    let onFilter: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            ToolbarButton(
                icon: "location.circle.fill",
                label: "Reset View",
                action: onReset
            )

            ToolbarButton(
                icon: "info.circle.fill",
                label: viewModel.selectedFlight != nil ? "Flight Info" : "No Flight",
                action: onInfo
            )

            ToolbarButton(
                icon: "arrow.up.arrow.down.circle",
                label: "Sort Flights",
                action: onSort
            )

            ToolbarButton(
                icon: "line.3.horizontal.decrease.circle",
                label: "Filter",
                action: onFilter
            )
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.isFocused) var isFocused

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                Text(label)
                    .font(.system(size: 24, weight: .semibold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(width: 280, height: 120)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isFocused ? .white : .clear, lineWidth: 3)
        )
        .scaleEffect(isFocused ? 1.15 : 1.0)
        .shadow(radius: isFocused ? 30 : 10)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct FlightInfoCard: View {
    let flight: Flight
    @ObservedObject var viewModel: FlightViewModel
    @Binding var showingDetail: Bool

    var body: some View {
        ZStack {
            // Map Layer
            Map(position: $viewModel.cameraPosition, interactionModes: []) {
                if !viewModel.selectedFlightPath.isEmpty {
                    MapPolyline(coordinates: viewModel.selectedFlightPath)
                        .stroke(Gradient(colors: [.clear, .yellow]), lineWidth: 4)
                }

                ForEach(viewModel.flights) { flight in
                    Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                        FlightAnnotationView(
                            flight: flight,
                            isFocused: false,
                            isSelected: viewModel.selectedFlight?.id == flight.id
                        )
                    }
                    .tag(flight.id)
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .mapControls {
                // Hide all map controls for cleaner view
            }
            .onMapCameraChange { context in
                viewModel.updateViewRegion(context.region)
            }
            .ignoresSafeArea()

            // UI Overlay
            VStack {
                Spacer()

                // Bottom Controls
                HStack(alignment: .bottom, spacing: 40) {
                    // Flight List (Left Side)
                    if !viewModel.flights.isEmpty {
                        flightListCard
                    }

                    Spacer()

                    // Map Controls (Right Side)
                    mapControlsPanel
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
            }

            // Full-width Bottom Bar
            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    private var mapControlsPanel: some View {
        VStack(spacing: 16) {
            Text("Map Controls")
                .font(.headline)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                // Zoom In Button
                Button {
                    viewModel.adjustZoom(multiplier: 0.8)
                } label: {
                    HStack {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.title3)
                        Text("Zoom In")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(MapControlButtonStyle())

                // Zoom Out Button
                Button {
                    viewModel.adjustZoom(multiplier: 1.25)
                } label: {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title3)
                        Text("Zoom Out")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(MapControlButtonStyle())

                // Reset View Button
                Button {
                    resetMapView()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.title3)
                        Text("Reset View")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(MapControlButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 6)
    }

    private var bottomBar: some View {
        HStack {
            // Title
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 28))
                    .symbolEffect(.pulse)
                Text("Eddie's Flight Tracker")
                    .font(.system(size: AppConfig.appTitleFontSize, weight: .heavy))
            }

            Spacer()

            // Status Info
            HStack(spacing: 20) {
                Text("\(viewModel.flights.count) Flights")
                    .font(.subheadline)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                }

                Text("Updates: \(Int(AppConfig.refreshInterval))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(AppConfig.provider.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }

    private var flightListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Flights")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Text("\(viewModel.flights.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.flights.prefix(15))) { flight in
                        Button {
                            selectFlight(flight)
                        } label: {
                            FlightListItem(
                                flight: flight,
                                isSelected: viewModel.selectedFlight?.id == flight.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 480)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 6)
    }

    // MARK: - Helper Functions

    private func selectFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            viewModel.selectFlight(flight)
            showingDetail = true
        }
    }

    private func resetMapView() {
        // Reset to initial map position (this should reference the parent ContentView's method)
        // For now, this is a placeholder that maintains current view
    }
}

// MARK: - Custom Button Style for Map Controls

struct MapControlButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .brightness(configuration.isPressed ? -0.2 : 0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Supporting Views (keeping existing implementations)

struct FlightListItem: View {
    let flight: Flight
    let isSelected: Bool
    @Environment(\.isFocused) var isFocused

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane")
                .font(.system(size: AppConfig.listIconSize))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(flight.track ?? 0))
                .frame(width: AppConfig.listIconSize + 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(flight.formattedCallsign)
                    .font(.system(size: AppConfig.listFontSize))
                    .fontWeight(.medium)
                Text(flight.originCountry)
                    .font(.system(size: AppConfig.listFontSize - 3))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(flight.formattedAltitude)
                    .font(.system(size: AppConfig.listFontSize - 3))
                    .foregroundStyle(.secondary)
                Text(flight.formattedVelocity)
                    .font(.system(size: AppConfig.listFontSize - 3))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            isFocused ? Color.white.opacity(0.3) :
            isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isFocused ? Color.white :
                    isSelected ? Color.white.opacity(0.6) : Color.clear,
                    lineWidth: isFocused ? 3 : isSelected ? 2 : 0
                )
        )
        .cornerRadius(8)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct SearchResultCard: View {
    let flight: Flight
    let isSelected: Bool
    @Environment(\.isFocused) var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(flight.formattedCallsign)
                    .font(.title3.weight(.semibold))
                Spacer()
                if isSelected {
                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                dataPill(icon: "globe.americas.fill", title: flight.originCountry)
                dataPill(icon: "arrow.up.to.line", title: flight.formattedAltitude)
                dataPill(icon: "speedometer", title: flight.formattedGroundSpeed)
            }

            Divider()
                .overlay(Color.white.opacity(0.1))

            HStack {
                Label(flight.aircraftType ?? "Unknown type", systemImage: "airplane")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(String(format: "Heading %.0f°", flight.track ?? 0), systemImage: "safari")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isSelected ? Color.white : Color.white.opacity(isFocused ? 0.25 : 0.12), lineWidth: isSelected ? 2 : 1)
                )
        )
        .shadow(color: isSelected ? Color.white.opacity(0.25) : Color.black.opacity(0.45), radius: isSelected ? 16 : 10, y: 6)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isFocused)
    }

    private func dataPill(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

struct SettingRow: View {
    let title: String
    let value: String
    let icon: String
    @Environment(\.isFocused) var isFocused

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: AppConfig.settingsLabelFontSize, weight: .semibold))
                Text(value)
                    .font(.system(size: AppConfig.settingsValueFontSize, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .background(isFocused ? .ultraThinMaterial : .thinMaterial)
        .cornerRadius(20)
        .focusable()
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// Flight Detail View
struct FlightDetailView: View {
    let flight: Flight
    @ObservedObject var viewModel: FlightViewModel
    @Binding var showingDetail: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header with Airline Info
                    VStack(spacing: 16) {
                        // Airline logo placeholder and name
                        if let airlineName = flight.airlineName {
                            HStack(spacing: 12) {
                                Image(systemName: "airplane.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(airlineName)
                                        .font(.system(size: AppConfig.detailLabelFontSize, weight: .bold))
                                }
                            }
                            .padding(.top, 80)
                        }

                        Image(systemName: "airplane")
                            .font(.system(size: 80))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(flight.track ?? 0))
                            .shadow(radius: 10)

                        Text(flight.formattedCallsign)
                            .font(.system(size: AppConfig.detailTitleFontSize, weight: .bold))
                    }
                    .padding(.top, flight.airlineName == nil ? 80 : 20)

                    // Primary Info Grid
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            CompactInfoCard(
                                icon: "flag.fill",
                                title: "Country",
                                value: flight.originCountry
                            )

                            if let registration = flight.registration {
                                CompactInfoCard(
                                    icon: "number",
                                    title: "Tail Number",
                                    value: registration
                                )
                            }

                            if let aircraftType = flight.aircraftType {
                                CompactInfoCard(
                                    icon: "airplane.departure",
                                    title: "Aircraft",
                                    value: aircraftType
                                )
                            }
                        }

                        HStack(spacing: 16) {
                            CompactInfoCard(
                                icon: "arrow.up.to.line",
                                title: "Altitude",
                                value: flight.formattedAltitude
                            )

                            CompactInfoCard(
                                icon: "speedometer",
                                title: "Ground Speed",
                                value: flight.formattedGroundSpeed
                            )

                            CompactInfoCard(
                                icon: "safari",
                                title: "Heading",
                                value: String(format: "%.0f°", flight.track ?? 0)
                            )
                        }

                        if let vert = flight.verticalRate {
                            HStack(spacing: 16) {
                                CompactInfoCard(
                                    icon: vert > 0 ? "arrow.up.right" : "arrow.down.right",
                                    title: "Vertical Rate",
                                    value: String(format: "%.0f ft/min", vert * 196.85),
                                    color: vert > 0 ? .green : .red
                                )

                                CompactInfoCard(
                                    icon: "location.fill",
                                    title: "ICAO24",
                                    value: flight.id.uppercased()
                                )

                                CompactInfoCard(
                                    icon: "globe",
                                    title: "Coordinates",
                                    value: String(format: "%.2f, %.2f",
                                                flight.coordinate.latitude,
                                                flight.coordinate.longitude)
                                )
                            }
                        }

                        if !viewModel.selectedFlightPath.isEmpty {
                            CompactInfoCard(
                                icon: "point.3.connected.trianglepath.dotted",
                                title: "Track Points",
                                value: "\(viewModel.selectedFlightPath.count) positions"
                            )
                        }
                    }
                    .padding(.horizontal, 100)

                    // Back Button
                    Button(action: {
                        withAnimation {
                            showingDetail = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.title3)
                            Text("Back to Map")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct CompactInfoCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: AppConfig.detailValueFontSize, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

#Preview {
    ContentView()
}
