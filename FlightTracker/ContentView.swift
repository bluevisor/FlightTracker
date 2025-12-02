import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = FlightViewModel()
    @State private var selectedTag: String?
    
    var body: some View {
        ZStack {
            // Map Layer
            Map(position: $viewModel.cameraPosition, selection: $selectedTag) {
                if !viewModel.selectedFlightPath.isEmpty {
                    MapPolyline(coordinates: viewModel.selectedFlightPath)
                        .stroke(Gradient(colors: [.clear, .yellow]), lineWidth: 4)
                }
                
                ForEach(viewModel.flights) { flight in
                    Annotation(flight.formattedCallsign, coordinate: flight.coordinate) {
                        FlightAnnotationView(flight: flight, isSelected: selectedTag == flight.id)
                    }
                    .tag(flight.id)
                }
            }
            .mapStyle(.hybrid(elevation: .realistic)) // Beautiful 3D map
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onChange(of: selectedTag) { oldValue, newValue in
                if let id = newValue, let flight = viewModel.flights.first(where: { $0.id == id }) {
                    viewModel.selectFlight(flight)
                } else {
                    viewModel.clearSelection()
                }
            }
            
            // UI Overlay Layer
            VStack {
                // Header
                HStack {
                    Image(systemName: "airplane.circle.fill")
                        .font(.largeTitle)
                        .symbolEffect(.pulse)
                    Text("Eddie's Flight Tracker")
                        .font(.title)
                        .fontWeight(.heavy)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.top, 40)
                .padding(.horizontal)
                
                Spacer()
                
                // Footer / Details
                HStack(alignment: .bottom) {
                    if let flight = viewModel.selectedFlight {
                        FlightDetailsCard(flight: flight)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Error Banner
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.top)
                        .transition(.move(edge: .top))
                }
                
                Spacer()
                    
                    // Stats
                    VStack(alignment: .trailing) {
                        Text("\(viewModel.flights.count) Flights Active")
                            .font(.headline)
                        Text("Data: OpenSky Network")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Swipe to Pan • Click to Select")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
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
