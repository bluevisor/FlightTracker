import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var selectedTab: Tab = .map
    @State private var showingFlightDetail = false
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var mapControlMode: MapControlMode = .pan
    @State private var showControlModeIndicator = false
    @FocusState private var focusedField: FocusableField?
    @State private var searchSelection: String?
    @State private var searchSort: SearchSortStyle = .relevance
    
    // Unit state for toggles
    @State private var speedUnit: AppConfig.SpeedUnit = AppConfig.speedUnit
    @State private var altitudeUnit: AppConfig.AltitudeUnit = AppConfig.altitudeUnit

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
        case settingsList
    }
    
    enum SearchSortStyle: String, CaseIterable {
        case relevance = "Relevance"
        case altitude = "Altitude"
        case speed = "Speed"
        
        var icon: String {
            switch self {
            case .relevance: return "sparkle.magnifyingglass"
            case .altitude: return "arrow.up.to.line"
            case .speed: return "speedometer"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main Content
            if showingFlightDetail, let flight = viewModel.selectedFlight {
                // Full-screen flight detail view
                FlightDetailView(flight: flight, viewModel: viewModel, showingDetail: $showingFlightDetail)
                    .transition(.move(edge: .bottom))
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
            // Selection persists when closing detail view
        }
        .onChange(of: mapControlMode) { _, _ in
            withAnimation { showControlModeIndicator = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showControlModeIndicator = false }
            }
        }
        // Sync config changes
        .onChange(of: speedUnit) { _, newValue in
            AppConfig.speedUnit = newValue
        }
        .onChange(of: altitudeUnit) { _, newValue in
            AppConfig.altitudeUnit = newValue
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .map {
                focusedField = .mapControls
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
            .onTapGesture {
                toggleMapControlMode()
            }
            .onMapCameraChange { context in
                viewModel.updateViewRegion(context.region)
            }
            .ignoresSafeArea()
            .onPlayPauseCommand {
                toggleFocusBetweenMapAndList()
            }
            .onMoveCommand { direction in
                guard focusedField == .mapControls, mapControlMode == .zoom else { return }
                switch direction {
                case .up, .right:
                    adjustZoom(multiplier: 0.8)
                case .down, .left:
                    adjustZoom(multiplier: 1.25)
                default:
                    break
                }
            }
            .focusable(true)
            .focused($focusedField, equals: .mapControls)
            .defaultFocus($focusedField, .mapControls)

            // UI Overlay
            VStack {
                // Control Mode Indicator
                if showControlModeIndicator {
                    HStack {
                        Spacer()

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
                .padding(.bottom, 60)
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
                        FlightListItem(
                            flight: flight,
                            isSelected: viewModel.selectedFlight?.id == flight.id,
                            isListFocused: focusedField == .flightList
                        )
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
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(focusedField == .flightList ? Color.white : Color.clear, lineWidth: focusedField == .flightList ? 2 : 0)
                )
        }
        .shadow(color: focusedField == .flightList ? Color.white.opacity(0.25) : Color.black.opacity(0.35), radius: focusedField == .flightList ? 12 : 8, y: 6)
        .focused($focusedField, equals: .flightList)
        .onMoveCommand { direction in
            guard focusedField == .flightList else { return }
            switch direction {
            case .up:
                moveFlightSelection(by: -1)
            case .down:
                moveFlightSelection(by: 1)
            default:
                break
            }
        }
        .onTapGesture {
            if let selected = viewModel.selectedFlight {
                selectFlight(selected)
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == .flightList {
                ensureFlightListSelection()
            }
        }
    }

    // MARK: - Search View

    private var searchView: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.14),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("Search flights by callsign, country, or airline", text: $viewModel.searchText)
                            .font(.title3.weight(.semibold))
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .searchField)
                            .submitLabel(.search)
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                                searchSelection = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.top, 36)

                    if orderedSearchResults.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "airplane.circle")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text(viewModel.searchText.isEmpty ? "Start typing to search" : "No flights found right now")
                                .font(.title3.weight(.semibold))
                            Text("Try a callsign, airline code, or country.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(orderedSearchResults) { flight in
                                SearchResultCard(
                                    flight: flight,
                                    isSelected: searchSelection == flight.id
                                )
                                .focusable()
                                .onTapGesture {
                                    searchSelection = flight.id
                                    selectFlight(flight)
                                    selectedTab = .map
                                }
                            }
                        }
                        .padding(.bottom, 60)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            focusedField = .searchField
            searchSelection = nil
        }
        .onChange(of: viewModel.searchText) { _, _ in
            searchSelection = nil
        }
    }
    
    private var orderedSearchResults: [Flight] {
        viewModel.filteredFlights
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 40) {
            Text("Settings")
                .font(.system(size: AppConfig.settingsTitleFontSize, weight: .bold))
                .padding(.top, 100)

            ScrollView {
                VStack(spacing: 20) {
                    // Unit Settings (New)
                    Text("Units")
                        .font(.system(size: AppConfig.settingsSectionHeaderFontSize, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 100)

                    HStack {
                        Text("Speed Unit")
                            .font(.system(size: AppConfig.settingsLabelFontSize, weight: .semibold))
                        Spacer()
                        Picker("Speed Unit", selection: $speedUnit) {
                            ForEach(AppConfig.SpeedUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                                    .font(.system(size: AppConfig.settingsValueFontSize))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                    }
                    .padding(24)
                    .background(.thinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 100)
                    .focused($focusedField, equals: .settingsList)

                    HStack {
                        Text("Altitude Unit")
                            .font(.system(size: AppConfig.settingsLabelFontSize, weight: .semibold))
                        Spacer()
                        Picker("Altitude Unit", selection: $altitudeUnit) {
                            ForEach(AppConfig.AltitudeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                                    .font(.system(size: AppConfig.settingsValueFontSize))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 360)
                    }
                    .padding(24)
                    .background(.thinMaterial)
                    .cornerRadius(20)
                    .padding(.horizontal, 100)

                    Divider()
                        .padding(.horizontal, 100)
                        .padding(.vertical, 20)

                    // API Settings
                    Text("API Settings")
                        .font(.system(size: AppConfig.settingsSectionHeaderFontSize, weight: .bold))
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
                    
                    // ... other settings
                }
            }
            Spacer()
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Helper Functions

    private func selectFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            viewModel.selectFlight(flight)
            showingFlightDetail = true
        }
    }
    
    private func highlightFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            viewModel.selectFlight(flight)
            showingFlightDetail = false
        }
    }
    
    private func toggleFocusBetweenMapAndList() {
        if focusedField == .flightList {
            focusedField = .mapControls
        } else {
            focusedField = .flightList
            ensureFlightListSelection()
        }
    }
    
    private func moveFlightSelection(by offset: Int) {
        let list = Array(viewModel.flights.prefix(15))
        guard !list.isEmpty else { return }
        
        let currentIndex = list.firstIndex(where: { $0.id == viewModel.selectedFlight?.id }) ?? -1
        let nextIndex = max(0, min(list.count - 1, currentIndex + offset))
        guard nextIndex != currentIndex else { return }
        let nextFlight = list[nextIndex]
        highlightFlight(nextFlight)
    }
    
    private func toggleMapControlMode() {
        withAnimation {
            mapControlMode = mapControlMode == .pan ? .zoom : .pan
        }
        focusedField = .mapControls
    }
    
    private func adjustZoom(multiplier: Double) {
        guard let region = viewModel.currentViewRegion else { return }
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(0.01, region.span.latitudeDelta * multiplier),
            longitudeDelta: max(0.01, region.span.longitudeDelta * multiplier)
        )
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        withAnimation {
            mapCameraPosition = .region(newRegion)
        }
        viewModel.updateViewRegion(newRegion)
    }
    
    private func ensureFlightListSelection() {
        let list = Array(viewModel.flights.prefix(15))
        guard !list.isEmpty else { return }
        
        if let selected = viewModel.selectedFlight,
           list.contains(where: { $0.id == selected.id }) {
            highlightFlight(selected)
            return
        }
        
        if let first = list.first {
            highlightFlight(first)
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
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 14)) // Small label
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

// MARK: - Supporting Views

struct FlightListItem: View {
    let flight: Flight
    let isSelected: Bool
    let isListFocused: Bool

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
        .background(rowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
        .cornerRadius(8)
        .scaleEffect((isListFocused && isSelected) ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isListFocused && isSelected)
    }
    
    private var rowBackground: Color {
        if isListFocused && isSelected { return Color.white.opacity(0.2) }
        return Color.white.opacity(0.05)
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
