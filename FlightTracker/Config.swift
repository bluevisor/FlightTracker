import Foundation

// MARK: - API Configuration

enum ADSBProvider: String, CaseIterable {
    case opensky = "OpenSky Network"
    case adsbLol = "adsb.lol"
    case adsbFi = "adsb.fi"
    case airplanesLive = "Airplanes.live"

    var requiresAuth: Bool {
        switch self {
        case .opensky:
            return false // Optional, falls back to anonymous
        case .adsbLol, .adsbFi, .airplanesLive:
            return false
        }
    }

    var baseURL: String {
        switch self {
        case .opensky:
            return "https://opensky-network.org/api"
        case .adsbLol:
            return "https://api.adsb.lol/v2"
        case .adsbFi:
            return "https://opendata.adsb.fi/api/v2"
        case .airplanesLive:
            return "http://api.airplanes.live/v2"
        }
    }

    var rateLimit: TimeInterval {
        switch self {
        case .opensky:
            return 60.0 // 60 seconds for anonymous, can be lower with auth
        case .adsbLol, .adsbFi, .airplanesLive:
            return 1.0 // 1 request per second
        }
    }

    var supportsGlobalView: Bool {
        switch self {
        case .opensky:
            return true // Has /states/all endpoint
        case .adsbLol, .adsbFi, .airplanesLive:
            return false // Only geographic/filtered queries
        }
    }

    var supportsHistoricalTracks: Bool {
        switch self {
        case .opensky:
            return true // Has /tracks/all endpoint
        case .adsbLol, .adsbFi, .airplanesLive:
            return false // No historical track endpoints
        }
    }

    var description: String {
        switch self {
        case .opensky:
            return "Global coverage, historical tracks, optional auth"
        case .adsbLol:
            return "Fast updates, 1 req/sec, no auth required"
        case .adsbFi:
            return "Personal use only, 1 req/sec, no auth"
        case .airplanesLive:
            return "Community-driven, 1 req/sec, no auth"
        }
    }
}

// MARK: - App Configuration

struct AppConfig {
    // API Provider Selection - Use regional APIs by default
    static var provider: ADSBProvider = .adsbLol

    // Geographic bounds (will use user location if available)
    // tvOS doesn't have GPS - set this to your home location for best results
    // Popular cities: SF (37.7749, -122.4194), NYC (40.7128, -74.0060), LA (34.0522, -118.2437)
    static var defaultLatitude: Double = 39.8283 // Center of US (default)
    static var defaultLongitude: Double = -98.5795
    static var defaultRadius: Double = 500.0 // 500 statute miles

    // Convert statute miles to nautical miles for API
    static var radiusInNauticalMiles: Double {
        return defaultRadius * 0.868976 // ~434 NM (under 250 NM limit, will be capped)
    }

    // Most APIs have 250 NM max
    static var apiRadius: Double {
        let nauticalMiles = radiusInNauticalMiles
        return min(nauticalMiles, 250.0)
    }

    // Performance settings
    static var maxFlightsToDisplay: Int = 500 // Limit for UI performance
    static var refreshInterval: TimeInterval {
        return 3.0 // Update every 3 seconds for smooth continuous updates
    }

    // Feature flags based on provider
    static var enableFlightSelection: Bool {
        return provider.supportsHistoricalTracks
    }

    // OpenSky authentication (optional)
    static var useOpenSkyAuth: Bool {
        return provider == .opensky && Secrets.clientSecret != "DhHI9vrwhuWNe7FcbIemEu220afIWXcN"
    }
}
