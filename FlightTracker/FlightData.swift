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

struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
}

class FlightService {
    private let provider: ADSBProvider
    private let authURL = "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token"

    private var accessToken: String?
    private var tokenExpiration: Date?

    init(provider: ADSBProvider = AppConfig.provider) {
        self.provider = provider
    }

    private func statesURL(lat: Double, lon: Double, radius: Double) -> String {
        switch provider {
        case .opensky:
            return "\(provider.baseURL)/states/all"
        case .adsbLol, .adsbFi, .airplanesLive:
            // Geographic query using provided location
            return "\(provider.baseURL)/lat/\(lat)/lon/\(lon)/dist/\(Int(radius))"
        }
    }

    private func trackURL(for icao24: String) -> String {
        switch provider {
        case .opensky:
            return "\(provider.baseURL)/tracks/all?icao24=\(icao24)&time=0"
        case .adsbLol, .adsbFi, .airplanesLive:
            // These APIs don't support historical tracks
            return ""
        }
    }
    
    private func getValidToken() async throws -> String {
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        
        guard Secrets.clientSecret != "YOUR_CLIENT_SECRET_HERE" else {
            throw NSError(domain: "FlightTracker", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing API Credentials"])
        }
        
        var request = URLRequest(url: URL(string: authURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=client_credentials&client_id=\(Secrets.clientId)&client_secret=\(Secrets.clientSecret)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Auth failed: \(String(data: data, encoding: .utf8) ?? "Unknown error")")
            throw NSError(domain: "FlightTracker", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        self.accessToken = tokenResponse.access_token
        self.tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in - 60)) // 60s buffer
        
        return tokenResponse.access_token
    }
    
    func fetchFlights(lat: Double? = nil, lon: Double? = nil, radius: Double? = nil) async throws -> [Flight] {
        // Use provided coordinates or fall back to config defaults
        let latitude = lat ?? AppConfig.defaultLatitude
        let longitude = lon ?? AppConfig.defaultLongitude
        let searchRadius = radius ?? AppConfig.apiRadius

        let urlString = statesURL(lat: latitude, lon: longitude, radius: searchRadius)
        print("📡 Fetching from: \(urlString)")
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        // Only try OpenSky authentication if using OpenSky and credentials present
        if provider == .opensky && AppConfig.useOpenSkyAuth {
            do {
                let token = try await getValidToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                print("Auth error, falling back to anonymous: \(error)")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📥 Response status: \(httpResponse.statusCode), data size: \(data.count) bytes")

        if httpResponse.statusCode == 429 {
            throw NSError(domain: "FlightTracker", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded. Please wait a moment."])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "FlightTracker", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
        }

        // Parse based on provider
        let flights: [Flight]
        switch provider {
        case .opensky:
            flights = try parseOpenSkyResponse(data)
        case .adsbLol, .adsbFi, .airplanesLive:
            flights = try parseADSBExchangeV2Response(data)
        }
        
        print("✈️ Parsed \(flights.count) flights from API")
        return flights
    }

    private func parseOpenSkyResponse(_ data: Data) throws -> [Flight] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let states = json["states"] as? [[Any]] else {
            return []
        }

        return states.compactMap { stateArray -> Flight? in
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

    private func parseADSBExchangeV2Response(_ data: Data) throws -> [Flight] {
        // ADSBExchange v2 format (used by adsb.lol, adsb.fi, airplanes.live)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let aircraft = json["ac"] as? [[String: Any]] else {
            return []
        }

        return aircraft.compactMap { ac -> Flight? in
            guard let hex = ac["hex"] as? String,
                  let lat = ac["lat"] as? Double,
                  let lon = ac["lon"] as? Double
            else { return nil }

            // Extract optional fields
            let callsign = (ac["flight"] as? String)?.trimmingCharacters(in: .whitespaces) ?? hex
            let country = ac["r"] as? String ?? "Unknown" // Registration as proxy for country
            let altBaro = ac["alt_baro"] as? Double // Altitude in feet
            let gs = ac["gs"] as? Double // Ground speed in knots
            let track = ac["track"] as? Double
            let baroRate = ac["baro_rate"] as? Double // Vertical rate in ft/min

            // Convert units to match OpenSky format (meters and m/s)
            let altitudeMeters = altBaro.map { $0 / 3.28084 }
            let velocityMPS = gs.map { $0 / 1.94384 }
            let verticalRateMPS = baroRate.map { $0 / 196.85 } // ft/min to m/s

            return Flight(
                id: hex,
                callsign: callsign,
                originCountry: country,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                altitude: altitudeMeters,
                velocity: velocityMPS,
                track: track,
                verticalRate: verticalRateMPS
            )
        }
    }
    
    func fetchTrack(for icao24: String) async throws -> [CLLocationCoordinate2D] {
        // Only OpenSky supports historical tracks
        guard provider.supportsHistoricalTracks else {
            return []
        }

        let urlString = trackURL(for: icao24)
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)

        if AppConfig.useOpenSkyAuth {
            if let token = try? await getValidToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = json["path"] as? [[Any]] else {
            return []
        }

        return path.compactMap { point in
            guard point.count >= 3,
                  let lat = point[1] as? Double,
                  let lon = point[2] as? Double else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}
