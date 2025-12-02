import SwiftUI
import MapKit
import Combine

@MainActor
class FlightViewModel: ObservableObject {
    @Published var flights: [Flight] = []
    @Published var selectedFlight: Flight?
    @Published var selectedFlightPath: [CLLocationCoordinate2D] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Camera position for the map
    @Published var cameraPosition: MapCameraPosition = .automatic
    
    private let service = FlightService()
    private var timer: Timer?
    
    init() {
        startFetching()
    }
    
    func startFetching() {
        isLoading = true
        Task {
            await fetchFlights()
            isLoading = false
        }
        
        // Fetch every 10 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.fetchFlights()
            }
        }
    }
    
    func fetchFlights() async {
        do {
            let allFlights = try await service.fetchFlights()
            // Filter for active flights (in air) and limit to avoid UI overload for this demo
            // In a production app, we might use clustering or tile-based loading
            let activeFlights = allFlights.filter {
                ($0.altitude ?? 0) > 0 && ($0.velocity ?? 0) > 0
            }
            
            // Update flights
            // We want to keep the selected flight if it still exists in the new data
            let currentSelectedId = selectedFlight?.id
            
            withAnimation {
                self.flights = activeFlights
                
                if let selectedId = currentSelectedId {
                    self.selectedFlight = activeFlights.first(where: { $0.id == selectedId })
                }
            }
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to load flight data: \(error.localizedDescription)"
        }
    }
    
    func selectFlight(_ flight: Flight) {
        withAnimation(.easeInOut) {
            selectedFlight = flight
            // Zoom to the flight
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: flight.coordinate,
                    distance: 500000, // 500km altitude view
                    heading: flight.track ?? 0,
                    pitch: 45
                )
            )
        }
        
        // Fetch track
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
    
    func clearSelection() {
        withAnimation {
            selectedFlight = nil
            selectedFlightPath = []
            cameraPosition = .automatic
        }
    }
}
