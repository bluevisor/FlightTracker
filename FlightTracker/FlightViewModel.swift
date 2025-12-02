import SwiftUI
import MapKit
import Combine
import CoreLocation

@MainActor
class FlightViewModel: ObservableObject {
    @Published var flights: [Flight] = []
    @Published var selectedFlight: Flight? {
        didSet {
            print("✈️ selectedFlight changed: \(oldValue?.formattedCallsign ?? "nil") → \(selectedFlight?.formattedCallsign ?? "nil")")
        }
    }
    @Published var selectedFlightPath: [CLLocationCoordinate2D] = []
    @Published var showUI = true
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Camera position for the map
    @Published var cameraPosition: MapCameraPosition = .automatic {
        didSet {
            if let region = cameraPosition.region {
                updateViewRegion(region)
            }
        }
    }

    // User location
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var currentViewRegion: MKCoordinateRegion?

    private let service = FlightService()
    private var timer: Timer?
    private let locationManager = CLLocationManager()
    
    init() {
        setupLocationManager()
        startFetching()
    }

    private func setupLocationManager() {
        #if os(tvOS)
        // tvOS doesn't support continuous location updates
        // Request one-time location authorization
        locationManager.requestWhenInUseAuthorization()

        // Try to get cached location if available
        if let location = locationManager.location {
            userLocation = location.coordinate
        } else {
            // tvOS: Use IP-based geolocation or default location
            // For now, use default configured location
            userLocation = CLLocationCoordinate2D(
                latitude: AppConfig.defaultLatitude,
                longitude: AppConfig.defaultLongitude
            )
        }
        #else
        // iOS/macOS: Full location services
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        if let location = locationManager.location {
            userLocation = location.coordinate
        }
        #endif
    }

    func startFetching() {
        // Start async fetch immediately in background (don't block UI)
        Task {
            isLoading = true
            await fetchFlights()
            isLoading = false
        }

        // Fetch based on refresh interval
        timer = Timer.scheduledTimer(withTimeInterval: AppConfig.refreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchFlights()
            }
        }
    }

    private var regionUpdateTask: Task<Void, Never>?
    
    func updateViewRegion(_ region: MKCoordinateRegion) {
        print("📐 updateViewRegion called: center(\(region.center.latitude), \(region.center.longitude)), span(\(region.span.latitudeDelta))")
        let previousRegion = currentViewRegion
        currentViewRegion = region
        
        // Check if region has changed significantly (moved or zoomed significantly)
        if let previous = previousRegion {
            let centerMoved = hasCenterMovedSignificantly(from: previous.center, to: region.center)
            let zoomChanged = hasZoomChangedSignificantly(from: previous.span, to: region.span)
            
            if centerMoved || zoomChanged {
                // Cancel any pending update
                regionUpdateTask?.cancel()
                
                // Debounce: wait 0.5 second after user stops moving before fetching new data
                regionUpdateTask = Task { @MainActor in
                    print("🗺️ Region changed, fetching flights in 0.5s...")
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                    
                    if !Task.isCancelled {
                        print("🔄 Fetching flights for new region: lat=\(region.center.latitude), lon=\(region.center.longitude)")
                        await fetchFlights()
                    }
                }
            }
        } else {
            // First time setting region, fetch immediately
            print("🗺️ Initial region set, fetching flights immediately...")
            Task {
                await fetchFlights()
            }
        }
    }
    
    private func hasCenterMovedSignificantly(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Bool {
        let latDiff = abs(from.latitude - to.latitude)
        let lonDiff = abs(from.longitude - to.longitude)
        // Consider it significant if moved more than 0.1 degrees (~7 miles)
        let moved = latDiff > 0.1 || lonDiff > 0.1
        if moved {
            print("📍 Center moved: Δlat=\(latDiff)°, Δlon=\(lonDiff)°")
        }
        return moved
    }
    
    private func hasZoomChangedSignificantly(from: MKCoordinateSpan, to: MKCoordinateSpan) -> Bool {
        let latDiff = abs(from.latitudeDelta - to.latitudeDelta)
        // Consider it significant if zoom changed by more than 10%
        let threshold = from.latitudeDelta * 0.1
        let changed = latDiff > threshold
        if changed {
            print("🔍 Zoom changed: Δspan=\(latDiff)° (threshold=\(threshold)°)")
        }
        return changed
    }
    
    func fetchFlights() async {
        print("🔄 Starting flight fetch...")
        do {
            // Use current view region if available (user has panned/zoomed), 
            // otherwise fall back to user location or defaults
            let lat = currentViewRegion?.center.latitude ?? userLocation?.latitude ?? AppConfig.defaultLatitude
            let lon = currentViewRegion?.center.longitude ?? userLocation?.longitude ?? AppConfig.defaultLongitude

            print("🎯 Using coordinates for fetch: lat=\(lat), lon=\(lon)")

            let allFlights = try await service.fetchFlights(
                lat: lat,
                lon: lon,
                radius: AppConfig.apiRadius
            )

            // Filter for active flights (in air)
            let activeFlights = allFlights.filter {
                ($0.altitude ?? 0) > 0 && ($0.velocity ?? 0) > 0
            }

            // Limit displayed flights for performance
            let limitedFlights = Array(activeFlights.prefix(AppConfig.maxFlightsToDisplay))
            
            print("✅ Fetched \(allFlights.count) raw flights, \(activeFlights.count) active, displaying \(limitedFlights.count)")

            // Update flights
            let currentSelectedId = selectedFlight?.id

            withAnimation {
                self.flights = limitedFlights

                if let selectedId = currentSelectedId {
                    // Re-bind selected flight to new data instance to update position/stats
                    if let updatedFlight = limitedFlights.first(where: { $0.id == selectedId }) {
                        self.selectedFlight = updatedFlight
                        print("🔄 Updated selected flight data for \(selectedId)")
                    } else {
                        print("⚠️ Selected flight \(selectedId) no longer in view/active")
                        // Optional: Deselect if flight is lost? 
                        // For now, keep it nil to let UI handle or keep stale data if we stored it separate
                        // But here we are just replacing the reference. 
                        // If we don't find it, selectedFlight becomes nil naturally if we didn't re-set it?
                        // No, 'self.selectedFlight' is a property. 
                        // If we don't update it, it holds the OLD flight object.
                        // This is actually GOOD for "persistence" if we want to keep showing details even if it flies out of range.
                        // BUT, the map annotation will disappear if it's not in 'flights'.
                    }
                }
            }
            self.errorMessage = nil
        } catch {
            let errorMsg = "Failed to load flight data: \(error.localizedDescription)"
            print("❌ FlightViewModel.fetchFlights error: \(error)")
            self.errorMessage = errorMsg
        }
    }
    
    func selectFlight(_ flight: Flight) {
        selectedFlight = flight

        // Fetch track if supported
        if AppConfig.provider.supportsHistoricalTracks {
            Task {
                do {
                    let path = try await service.fetchTrack(for: flight.id)
                    await MainActor.run {
                        withAnimation {
                            self.selectedFlightPath = path
                        }
                    }
                } catch {
                    print("Failed to fetch track: \(error)")
                    await MainActor.run {
                        self.selectedFlightPath = []
                    }
                }
            }
        }
    }
    
    func clearSelection() {
        withAnimation {
            selectedFlight = nil
            selectedFlightPath = []
        }
    }
    
    var filteredFlights: [Flight] {
        if searchText.isEmpty {
            return flights
        } else {
            return flights.filter {
                $0.callsign.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                $0.originCountry.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    
    // MARK: - Map Control
    
    func adjustZoom(multiplier: Double) {
        guard let region = currentViewRegion else {
            return
        }
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(0.01, min(180.0, region.span.latitudeDelta * multiplier)),
            longitudeDelta: max(0.01, min(360.0, region.span.longitudeDelta * multiplier))
        )
        let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        withAnimation(.linear(duration: 0.05)) {
            cameraPosition = .region(newRegion)
        }
        updateViewRegion(newRegion)
    }
}
