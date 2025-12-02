import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var selectedTab: Tab = .map
    @State private var selectedFlight: Flight?
    @State private var showingFlightDetail = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapControlMode: MapControlMode = .pan
    @State private var showControlModeIndicator = false
    @FocusState private var focusedField: FocusableField?

    enum MapControlMode {
        case pan
        case zoom
    }


    enum Tab: String, CaseIterable {
        case map = "Map"
        case search = "Search"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .map: return "map.fill"
            case .search: return "magnifyingglass"
            case .settings: return "gearshape.fill"
            }
        }
    }

    enum FocusableField: Hashable {
        case searchField
        case flightList
        case mapControls
        case tabBar
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main Content
            if showingFlightDetail, let flight = selectedFlight {
                // Full-screen flight detail view
                FlightDetailView(flight: flight, viewModel: viewModel, showingDetail: $showingFlightDetail)
                    .transition(.move(edge: .trailing))
            } else {
                // Main tab view
                TabView(selection: $selectedTab) {
                    mapView
                        .tag(Tab.map)
                        .tabItem {
                            Label("Map", systemImage: "map.fill")
                        }

                    searchView
                        .tag(Tab.search)
                        .tabItem {
                            Label("Search", systemImage: "magnifyingglass")
                        }

                    settingsView
                        .tag(Tab.settings)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupInitialMapPosition()
            showControlModeIndicator = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showControlModeIndicator = false }
            }
        }
        .onChange(of: showingFlightDetail) { oldValue, newValue in
            if !newValue {
                selectedFlight = nil
            }
        }
        .onChange(of: mapControlMode) { _, _ in
            withAnimation { showControlModeIndicator = true }
            // Cancel previous timer? Simple delay is enough for now
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showControlModeIndicator = false }
            }
        }
    }

    // MARK: - Map View

    private var mapView: some View {
        ZStack {
            // Map Layer
            Map(position: $mapCameraPosition, interactionModes: mapControlMode == .pan ? [.pan] : [.zoom]) {
                if !viewModel.selectedFlightPath.isEmpty {
                    MapPolyline(coordinates: viewModel.selectedFlightPath)
                        .stroke(Gradient(colors: [.clear, .yellow]), lineWidth: 4)
                }

                ForEach(viewModel.flights) { flight in
                    Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                        FlightAnnotationView(
                            flight: flight,
                            isSelected: selectedFlight?.id == flight.id
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
                // Control Mode Indicator (Center Top)
                if showControlModeIndicator {
                    HStack {
                        Spacer()

                        Button(action: {
                            withAnimation {
                                mapControlMode = mapControlMode == .pan ? .zoom : .pan
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: mapControlMode == .pan ? "arrow.up.and.down.and.arrow.left.and.right" : "plus.magnifyingglass")
                                    .font(.title2)
                                Text(mapControlMode == .pan ? "Pan Mode" : "Zoom Mode")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .shadow(radius: 10)
                        }
                        .buttonStyle(.plain)
                        .focusable()

                        Spacer()
                    }
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Bottom Controls
                HStack(alignment: .bottom, spacing: 40) {
                    // Flight List (Left Side)
                    if !viewModel.flights.isEmpty {
                        flightListCard
                    }

                    Spacer()
                }
                .padding(.leading, 30)
                .padding(.bottom, 60) // Space for bottom bar (reduced from 80)
            }

            // Full-width Bottom Bar
            VStack {
                Spacer()
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            // Title
            HStack(spacing: 12) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 28))
                    .symbolEffect(.pulse)
                Text("Eddie's Flight Tracker")
                    .font(.system(size: 24, weight: .heavy))
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
        .padding(.vertical, 10)
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
                        FlightListItem(flight: flight, isSelected: selectedFlight?.id == flight.id)
                            .focusable()
                            .onTapGesture {
                                selectFlight(flight)
                            }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 480)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Search View

    private var searchView: some View {
        VStack(spacing: 40) {
            Text("Search Flights")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)

            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(.secondary)
                TextField("Enter callsign or country...", text: $viewModel.searchText)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .searchField)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .padding(.horizontal, 100)

            // Search Results
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(viewModel.filteredFlights) { flight in
                        SearchResultCard(flight: flight, isSelected: selectedFlight?.id == flight.id)
                            .focusable()
                            .onTapGesture {
                                selectFlight(flight)
                                selectedTab = .map
                            }
                    }
                }
                .padding(.horizontal, 100)
            }

            Spacer()
        }
        .background(Color.black.opacity(0.3))
        .onAppear {
            focusedField = .searchField
        }
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 40) {
            Text("Settings")
                .font(.system(size: 48, weight: .bold))
                .padding(.top, 100)

            ScrollView {
                VStack(spacing: 20) {
                    // API Settings
                    Text("API Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 100)

                    SettingRow(
                        title: "Data Source",
                        value: AppConfig.provider.rawValue,
                        icon: "antenna.radiowaves.left.and.right"
                    )

                    SettingRow(
                        title: "Refresh Interval",
                        value: "\(Int(AppConfig.refreshInterval)) seconds",
                        icon: "clock.fill"
                    )

                    SettingRow(
                        title: "Radius",
                        value: "\(Int(AppConfig.defaultRadius)) miles",
                        icon: "location.circle.fill"
                    )

                    SettingRow(
                        title: "Location",
                        value: String(format: "%.4f, %.4f", AppConfig.defaultLatitude, AppConfig.defaultLongitude),
                        icon: "mappin.circle.fill"
                    )

                    Divider()
                        .padding(.horizontal, 100)
                        .padding(.vertical, 20)

                    // Display Settings
                    Text("Display Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 100)

                    SettingRow(
                        title: "Map Icon Size",
                        value: "\(Int(AppConfig.mapIconSize)) pt",
                        icon: "airplane"
                    )

                    SettingRow(
                        title: "List Icon Size",
                        value: "\(Int(AppConfig.listIconSize)) pt",
                        icon: "list.bullet"
                    )

                    SettingRow(
                        title: "List Font Size",
                        value: "\(Int(AppConfig.listFontSize)) pt",
                        icon: "textformat.size"
                    )

                    SettingRow(
                        title: "Search Icon Size",
                        value: "\(Int(AppConfig.searchIconSize)) pt",
                        icon: "magnifyingglass"
                    )

                    SettingRow(
                        title: "Search Font Size",
                        value: "\(Int(AppConfig.searchFontSize)) pt",
                        icon: "textformat"
                    )
                }
                .padding(.horizontal, 100)
            }

            Spacer()

            Text("Edit Config.swift to change settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 60)
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Helper Functions

    private func selectFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            selectedFlight = flight
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
            span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
        )
        mapCameraPosition = .region(region)
        viewModel.updateViewRegion(region)
    }
}

// MARK: - Flight Detail View

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
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    if let code = flight.airlineCode {
                                        Text("Code: \(code)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
                            .font(.system(size: 48, weight: .bold))
                    }
                    .padding(.top, flight.airlineName == nil ? 80 : 20)

                    // Primary Info Grid (2x3)
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
                                title: "Speed",
                                value: flight.formattedVelocity
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
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.title)
                            Text("Back to Map")
                                .font(.headline)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 40)
                }
            }
        }
        .onExitCommand {
            withAnimation {
                showingDetail = false
            }
        }
    }
}

// Compact info card for detail view
struct CompactInfoCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct FlightListItem: View {
    let flight: Flight
    let isSelected: Bool
    @Environment(\.isFocused) var isFocused

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane")
                .font(.system(size: AppConfig.listIconSize))
                .foregroundStyle(isSelected ? .yellow : .white)
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
        .background(isFocused ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
        .cornerRadius(8)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct SearchResultCard: View {
    let flight: Flight
    let isSelected: Bool
    @Environment(\.isFocused) var isFocused

    private var cardBackground: some View {
        ZStack {
            Color.white.opacity(0.05)
            if isFocused || isSelected {
                Color.blue.opacity(0.3).blendMode(.screen)
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(isFocused || isSelected ? Color.yellow.opacity(0.8) : Color.clear, lineWidth: 3)
    }

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: AppConfig.searchIconSize))
                .foregroundStyle(isFocused || isSelected ? .yellow : .white)
                .rotationEffect(.degrees(flight.track ?? 0))

            VStack(alignment: .leading, spacing: 6) {
                Text(flight.formattedCallsign)
                    .font(.system(size: AppConfig.searchFontSize, weight: .bold))
                Text(flight.originCountry)
                    .font(.system(size: AppConfig.searchFontSize - 4))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(flight.formattedAltitude)
                    .font(.system(size: AppConfig.searchFontSize - 2))
                Text(flight.formattedVelocity)
                    .font(.system(size: AppConfig.searchFontSize - 6))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .background(cardBackground)
        .background(.thinMaterial)
        .cornerRadius(20)
        .overlay(cardBorder)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
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
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
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

struct FlightAnnotationView: View {
    let flight: Flight
    let isSelected: Bool

    var body: some View {
        Image(systemName: "airplane")
            .resizable()
            .scaledToFit()
            .frame(
                width: isSelected ? AppConfig.mapIconSizeSelected : AppConfig.mapIconSize,
                height: isSelected ? AppConfig.mapIconSizeSelected : AppConfig.mapIconSize
            )
            .rotationEffect(.degrees(flight.track ?? 0))
            .foregroundStyle(isSelected ? .yellow : .white)
            .shadow(radius: isSelected ? 10 : 2)
            .animation(.spring, value: isSelected)
    }
}

#Preview {
    ContentView()
}
