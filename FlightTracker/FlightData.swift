import Foundation
import CoreLocation

// MARK: - Models

struct Flight: Identifiable, Hashable {
    let id: String // icao24
    let callsign: String
    let originCountry: String
    let coordinate: CLLocationCoordinate2D
    let altitude: Double? // meters
    let velocity: Double? // m/s
    let track: Double? // degrees
    let verticalRate: Double? // m/s
    
    // Helper for formatting
    var formattedCallsign: String {
        callsign.trimmingCharacters(in: .whitespaces)
    }
    
    var formattedAltitude: String {
        guard let alt = altitude else { return "N/A" }
        return String(format: "%.0f ft", alt * 3.28084)
    }
    
    var formattedVelocity: String {
        guard let vel = velocity else { return "N/A" }
        return String(format: "%.0f kts", vel * 1.94384)
    }
    
    static func == (lhs: Flight, rhs: Flight) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Service

class FlightService {
    private let baseURL = "https://opensky-network.org/api/states/all"
    private let trackURL = "https://opensky-network.org/api/tracks/all"
    
    func fetchFlights() async throws -> [Flight] {
        guard let url = URL(string: baseURL) else { return [] }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30 // Fail faster if connection is bad
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 429 {
            throw NSError(domain: "FlightTracker", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded. Please wait a moment."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "FlightTracker", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }
        
        // Use JSONSerialization for performance with large mixed-type arrays
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let states = json["states"] as? [[Any]] else {
            return []
        }
        
        return states.compactMap { stateArray -> Flight? in
            // Index mapping:
            // 0: icao24 (String)
            // 1: callsign (String)
            // 2: origin_country (String)
            // 5: longitude (Double)
            // 6: latitude (Double)
            // 7: baro_altitude (Double)
            // 9: velocity (Double)
            // 10: true_track (Double)
            // 11: vertical_rate (Double)
            
            guard stateArray.count > 11,
                  let icao = stateArray[0] as? String,
                  let callsign = stateArray[1] as? String,
                  let country = stateArray[2] as? String,
                  let lon = stateArray[5] as? Double,
                  let lat = stateArray[6] as? Double
            else { return nil }
            
            let altitude = stateArray[7] as? Double
            let velocity = stateArray[9] as? Double
            let track = stateArray[10] as? Double
            let verticalRate = stateArray[11] as? Double
            
            return Flight(
                id: icao,
                callsign: callsign,
                originCountry: country,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: altitude,
                velocity: velocity,
                track: track,
                verticalRate: verticalRate
            )
        }
    }
    
    func fetchTrack(for icao24: String) async throws -> [CLLocationCoordinate2D] {
        guard let url = URL(string: "\(trackURL)?icao24=\(icao24)&time=0") else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["path"] as? [[Any]] else {
            return []
        }
        
        return path.compactMap { point in
            // path point: [time, lat, lon, alt, heading, onGround]
            guard point.count >= 3,
                  let lat = point[1] as? Double,
                  let lon = point[2] as? Double else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
