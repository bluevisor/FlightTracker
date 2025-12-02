import Foundation
import CoreLocation

// MARK: - Models

struct Flight: Identifiable, Hashable {
    let id: String // icao24
    let callsign: String
    let originCountry: String
    let registration: String? // Tail number (e.g., N12345)
    let aircraftType: String? // Aircraft model
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

    // Extract airline code from callsign (first 3 chars typically)
    var airlineCode: String? {
        let cleaned = formattedCallsign
        guard cleaned.count >= 3 else { return nil }
        let code = String(cleaned.prefix(3))
        // Check if it's actually an airline code (letters only)
        guard code.allSatisfy({ $0.isLetter }) else { return nil }
        return code
    }

    // Get airline name from IATA/ICAO code
    var airlineName: String? {
        guard let code = airlineCode else { return nil }
        return AirlineDatabase.getName(for: code)
    }

    static func == (lhs: Flight, rhs: Flight) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Simple airline database
struct AirlineDatabase {
    static let airlines: [String: String] = [
        "AAL": "American Airlines",
        "AAR": "Asiana Airlines",
        "ACA": "Air Canada",
        "AFR": "Air France",
        "AIC": "Air India",
        "ALK": "SriLankan Airlines",
        "ANA": "All Nippon Airways",
        "ANZ": "Air New Zealand",
        "ASA": "Alaska Airlines",
        "AUA": "Austrian Airlines",
        "AWE": "US Airways",
        "AXM": "AirAsia",
        "BAW": "British Airways",
        "CCA": "Air China",
        "CES": "China Eastern",
        "CPA": "Cathay Pacific",
        "CSN": "China Southern",
        "DAL": "Delta Air Lines",
        "DLH": "Lufthansa",
        "EIN": "Aer Lingus",
        "ELY": "El Al",
        "ETH": "Ethiopian Airlines",
        "EVA": "EVA Air",
        "FDX": "FedEx",
        "FFT": "Frontier Airlines",
        "FIN": "Finnair",
        "GIA": "Garuda Indonesia",
        "HAL": "Hawaiian Airlines",
        "IBE": "Iberia",
        "JAL": "Japan Airlines",
        "JAI": "Jet Airways",
        "JBU": "JetBlue Airways",
        "KAL": "Korean Air",
        "KLM": "KLM",
        "MAS": "Malaysia Airlines",
        "MEA": "Middle East Airlines",
        "NKS": "Spirit Airlines",
        "NWA": "Northwest Airlines",
        "QFA": "Qantas",
        "QTR": "Qatar Airways",
        "ROU": "Air Canada Rouge",
        "RYR": "Ryanair",
        "SAA": "South African Airways",
        "SAS": "SAS Scandinavian Airlines",
        "SIA": "Singapore Airlines",
        "SKW": "SkyWest Airlines",
        "SWA": "Southwest Airlines",
        "SWR": "Swiss International Air Lines",
        "TAM": "LATAM Airlines",
        "TAP": "TAP Air Portugal",
        "THA": "Thai Airways",
        "THY": "Turkish Airlines",
        "UAL": "United Airlines",
        "UAE": "Emirates",
        "UPS": "UPS Airlines",
        "VIR": "Virgin Atlantic",
        "VOZ": "Virgin Australia"
    ]

    static func getName(for code: String) -> String? {
        return airlines[code.uppercased()]
    }
}

// Country lookup by tail number prefix
struct TailNumberCountryDatabase {
    static let prefixes: [String: String] = [
        "N": "United States",
        "C": "Canada",
        "G": "United Kingdom",
        "D": "Germany",
        "F": "France",
        "I": "Italy",
        "JA": "Japan",
        "HL": "South Korea",
        "B": "China",
        "VH": "Australia",
        "ZK": "New Zealand",
        "PH": "Netherlands",
        "OO": "Belgium",
        "OY": "Denmark",
        "SE": "Sweden",
        "LN": "Norway",
        "OH": "Finland",
        "SP": "Poland",
        "HA": "Hungary",
        "OK": "Czech Republic",
        "YR": "Romania",
        "LZ": "Bulgaria",
        "SX": "Greece",
        "CS": "Portugal",
        "EC": "Spain",
        "HB": "Switzerland",
        "OE": "Austria",
        "9H": "Malta",
        "EI": "Ireland",
        "TC": "Turkey",
        "RA": "Russia",
        "UR": "Ukraine",
        "LY": "Lithuania",
        "YL": "Latvia",
        "ES": "Estonia",
        "A6": "United Arab Emirates",
        "A7": "Qatar",
        "HZ": "Saudi Arabia",
        "AP": "Pakistan",
        "VT": "India",
        "9M": "Malaysia",
        "9V": "Singapore",
        "HS": "Thailand",
        "XU": "Cambodia",
        "XY": "Myanmar",
        "RP": "Philippines",
        "PK": "Indonesia",
        "DQ": "Fiji",
        "ZS": "South Africa",
        "5Y": "Kenya",
        "ET": "Ethiopia",
        "SU": "Egypt",
        "CN": "Morocco",
        "PT": "Brazil",
        "CC": "Chile",
        "CP": "Bolivia",
        "HC": "Ecuador",
        "HK": "Colombia",
        "LV": "Argentina",
        "XA": "Mexico",
        "XB": "Mexico",
        "XC": "Mexico",
        "YV": "Venezuela"
    ]

    static func getCountry(for registration: String?) -> String? {
        guard let reg = registration?.uppercased(), !reg.isEmpty else { return nil }

        // Try 2-letter prefixes first
        if reg.count >= 2 {
            let twoChar = String(reg.prefix(2))
            if let country = prefixes[twoChar] {
                return country
            }
        }

        // Try 1-letter prefix
        let oneChar = String(reg.prefix(1))
        return prefixes[oneChar]
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
                registration: nil, // OpenSky doesn't provide registration
                aircraftType: nil, // OpenSky doesn't provide aircraft type
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
            let registration = ac["r"] as? String // Tail number (e.g., N12345)
            let descCountry = ac["desc"] as? String // Country from description field
            let aircraftType = ac["t"] as? String // Aircraft type (e.g., B738)
            let altBaro = ac["alt_baro"] as? Double // Altitude in feet
            let gs = ac["gs"] as? Double // Ground speed in knots
            let track = ac["track"] as? Double
            let baroRate = ac["baro_rate"] as? Double // Vertical rate in ft/min

            // Determine country: prioritize lookup from tail number if description is missing or generic
            var country: String = "Unknown"
            
            // First try to lookup from registration/tail number if available
            if let lookupCountry = TailNumberCountryDatabase.getCountry(for: registration) {
                country = lookupCountry
            } else if let desc = descCountry, !desc.isEmpty, desc != "Unknown" {
                // Fallback to description if lookup failed
                country = desc
            }

            // Convert units to match OpenSky format (meters and m/s)
            let altitudeMeters = altBaro.map { $0 / 3.28084 }
            let velocityMPS = gs.map { $0 / 1.94384 }
            let verticalRateMPS = baroRate.map { $0 / 196.85 } // ft/min to m/s

            return Flight(
                id: hex,
                callsign: callsign,
                originCountry: country,
                registration: registration,
                aircraftType: aircraftType,
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
