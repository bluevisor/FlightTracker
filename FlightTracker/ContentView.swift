import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var selectedTag: String?
    @FocusState private var isSearchFocused: Bool
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            // Map Layer
            mapView
                .focusable(viewModel.controlMode == .pan || viewModel.controlMode == .zoom)
                .onMoveCommand { direction in
                    handleDirectionKey(direction)
                }

            // UI Overlay
            if viewModel.showUI {
                VStack(alignment: .leading, spacing: 0) {
                    // Top Left: Title
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: "airplane.circle.fill")
                                .font(.largeTitle)
                                .symbolEffect(.pulse)
                            Text("Eddie's Flight Tracker")
                                .font(.title)
                                .fontWeight(.heavy)
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)

                        Spacer()
                    }
                    .padding(.top, 40)
                    .padding(.leading)

                    Spacer()

                    // Bottom: Flight Details (left) and Stats (right)
                    HStack(alignment: .bottom) {
                        if let flight = viewModel.selectedFlight {
                            FlightDetailsCard(flight: flight)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        Spacer()

                        // Stats Card (Bottom Right)
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("\(viewModel.flights.count) Flights Active")
                                .font(.headline)
                            Text("Data: \(AppConfig.provider.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Updates: \(Int(AppConfig.refreshInterval))s")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            Divider()

                            if viewModel.showControlMode {
                                // Control Mode Indicator
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.controlMode.icon)
                                        .font(.title3)
                                    Text(viewModel.controlMode.rawValue)
                                        .font(.headline)
                                }
                                .foregroundStyle(.yellow)
                                .padding(.vertical, 4)

                                Text("Press Center to Switch")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text("Hold Center to Exit")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Press Center for Controls")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                    .padding()
                }
                .transition(.opacity)
            }

            // Search Overlay (only in search mode)
            if viewModel.showUI && viewModel.showControlMode && viewModel.controlMode == .search {
                VStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                        TextField("Search Flight or Country", text: $viewModel.searchText)
                            .focused($isSearchFocused)
                            .textFieldStyle(.plain)
                            .font(.title3)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.top, 160) // Moved down to avoid title overlap
                    .padding(.horizontal, 40)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Error Banner
            if let error = viewModel.errorMessage {
                VStack {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.top, 120)
                        .transition(.move(edge: .top))
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .onPlayPauseCommand {
            withAnimation {
                viewModel.showUI.toggle()
            }
        }
        // Short press center: cycle modes (when control mode is active)
        // Long press center: toggle control mode UI
        .onTapGesture {
            handleCenterPress()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            handleLongCenterPress()
        }
    }

    private var mapView: some View {
        Map(position: $mapCameraPosition, interactionModes: mapInteractionModes, selection: $selectedTag) {
            mapContent
        }
        .mapStyle(.hybrid(elevation: .realistic))
        .mapControls {
            #if !os(tvOS)
            MapUserLocationButton()
            #endif
            MapCompass()
        }
        .onChange(of: selectedTag) {
            handleSelectionChange(oldValue: nil, newValue: selectedTag)
        }
        .onMapCameraChange { context in
            viewModel.updateViewRegion(context.region)
        }
        .onAppear(perform: setupInitialMapPosition)
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        if !viewModel.selectedFlightPath.isEmpty {
            MapPolyline(coordinates: viewModel.selectedFlightPath)
                .stroke(Gradient(colors: [.clear, .yellow]), lineWidth: 4)
        }

        ForEach(displayedFlights) { flight in
            Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                FlightAnnotationView(flight: flight, isSelected: selectedTag == flight.id)
            }
            .tag(flight.id)
        }
    }

    private func handleSelectionChange(oldValue: String?, newValue: String?) {
        if viewModel.controlMode == .select {
            if let id = newValue, let flight = viewModel.flights.first(where: { $0.id == id }) {
                viewModel.selectFlight(flight)
            } else {
                viewModel.clearSelection()
            }
        }
    }

    private func handleCameraPositionChange(oldValue: MapCameraPosition, newValue: MapCameraPosition) {
        // No-op: We track region via onMapCameraChange
    }

    private func setupInitialMapPosition() {
        // Set initial position immediately - use user location if available, otherwise default
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

    private var displayedFlights: [Flight] {
        // In search mode, show filtered flights
        if viewModel.controlMode == .search {
            return viewModel.filteredFlights
        }
        return viewModel.flights
    }

    private var mapInteractionModes: MapInteractionModes {
        switch viewModel.controlMode {
        case .pan:
            return [.pan]
        case .zoom:
            return [.zoom]
        case .select:
            return [.pan, .zoom]
        case .search:
            return []
        }
    }

    private func handleCenterPress() {
        if viewModel.showControlMode {
            withAnimation {
                viewModel.nextControlMode()
                // Focus search field when entering search mode
                if viewModel.controlMode == .search {
                    isSearchFocused = true
                }
            }
        } else {
            withAnimation {
                viewModel.showControlMode = true
            }
        }
    }

    private func handleLongCenterPress() {
        withAnimation {
            viewModel.showControlMode.toggle()
            if !viewModel.showControlMode {
                // Reset to pan mode when exiting
                viewModel.controlMode = .pan
                viewModel.searchText = ""
                isSearchFocused = false
            }
        }
    }

    private func handleDirectionKey(_ direction: MoveCommandDirection) {
        switch viewModel.controlMode {
        case .pan:
            panMap(direction)
        case .zoom:
            zoomMap(direction)
        default:
            break
        }
    }

    private func getCurrentRegion() -> MKCoordinateRegion? {
        return viewModel.currentViewRegion
    }

    private func panMap(_ direction: MoveCommandDirection) {
        guard let region = getCurrentRegion() else { return }

        // Pan by 15% of screen for faster movement
        let panAmount = region.span.latitudeDelta * 0.3 
        var newRegion = region

        switch direction {
        case .up:
            newRegion.center.latitude += panAmount
        case .down:
            newRegion.center.latitude -= panAmount
        case .left:
            newRegion.center.longitude -= panAmount
        case .right:
            newRegion.center.longitude += panAmount
        @unknown default:
            break
        }

        // Very short animation for smooth but immediate response
        withAnimation(.easeInOut(duration: 0.05)) {
            mapCameraPosition = .region(newRegion)
        }
    }

    private func zoomMap(_ direction: MoveCommandDirection) {
        guard let region = getCurrentRegion() else { return }

        let zoomFactor = 1.05
        var newRegion = region

        switch direction {
        case .up: // Zoom in
            newRegion.span.latitudeDelta /= zoomFactor
            newRegion.span.longitudeDelta /= zoomFactor
        case .down: // Zoom out
            newRegion.span.latitudeDelta *= zoomFactor
            newRegion.span.longitudeDelta *= zoomFactor
        case .left, .right:
            break
        @unknown default:
            break
        }

        // Very short animation for smooth but immediate response
        withAnimation(.easeInOut(duration: 0.05)) {
            mapCameraPosition = .region(newRegion)
        }
    }
}

// MARK: - Subviews

struct FlightAnnotationView: View {
    let flight: Flight
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "airplane")
                .resizable()
                .scaledToFit()
                .frame(width: isSelected ? 40 : 20, height: isSelected ? 40 : 20)
                .rotationEffect(.degrees(flight.track ?? 0))
                .foregroundStyle(isSelected ? .yellow : .white)
                .shadow(radius: isSelected ? 10 : 2)

            if isSelected {
                Text(flight.formattedCallsign)
                    .font(.caption)
                    .bold()
                    .padding(4)
                    .background(.black.opacity(0.7))
                    .cornerRadius(4)
                    .offset(y: 5)
            }
        }
        .animation(.spring, value: isSelected)
    }
}

struct FlightDetailsCard: View {
    let flight: Flight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(flight.formattedCallsign)
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Text(flight.originCountry)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 20) {
                DetailItem(icon: "arrow.up.to.line", title: "Altitude", value: flight.formattedAltitude)
                DetailItem(icon: "speedometer", title: "Speed", value: flight.formattedVelocity)
                DetailItem(icon: "safari", title: "Track", value: String(format: "%.0f°", flight.track ?? 0))
            }

            if let vert = flight.verticalRate, vert != 0 {
                HStack {
                    Image(systemName: vert > 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(vert > 0 ? "Climbing" : "Descending")
                    Text(String(format: "%.1f m/s", abs(vert)))
                }
                .font(.subheadline)
                .foregroundStyle(vert > 0 ? .green : .red)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct DetailItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .bold()
        }
    }
}

#Preview {
    ContentView()
}
