# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eddie's Flight Tracker is a real-time flight tracking application for Apple TV built with SwiftUI and MapKit. It displays live flight data from the OpenSky Network API on an interactive 3D map.

## Build and Run

- **Build**: Open `FlightTracker.xcodeproj` in Xcode and press ⌘B
- **Run**: Select an Apple TV simulator or device, then press ⌘R
- **Requirements**: Xcode 15.0+, tvOS 17.0+

## Architecture

The app follows MVVM architecture with three core files:

### FlightData.swift
- **Models**: `Flight` struct with computed properties for formatted display (altitude in feet, velocity in knots)
- **Network Service**: `FlightService` handles OpenSky Network API communication
  - OAuth2 token management with automatic refresh (60s buffer before expiration)
  - Falls back to anonymous API access if credentials missing
  - Primary endpoint: `/api/states/all` for all active flights
  - Track endpoint: `/api/tracks/all?icao24={id}&time=0` for flight paths
  - Rate limit handling (429 errors)

### FlightViewModel.swift
- **State Management**: ObservableObject managing flights array, selection state, and camera position
- **Auto-refresh**: Timer-based polling every 60 seconds to respect API rate limits
- **Flight Filtering**: Filters for active flights (altitude > 0, velocity > 0) and search results
- **Camera Control**: Animates to selected flight with 500km altitude, pitch 45°, heading matching flight track

### ContentView.swift
- **Map Display**: MapKit with hybrid elevation style showing 3D terrain
- **Annotations**: Custom `FlightAnnotationView` with airplane icons rotated by flight track
- **Flight Path**: Yellow gradient polyline for selected flight's historical trajectory
- **UI Overlay**: Glassmorphism design with header, flight details card, and stats footer
- **Interaction**: Tag-based selection system where `selectedTag` drives the selection state

## API Configuration

The app supports multiple ADS-B data providers through `Config.swift`:

### Available Providers

1. **OpenSky Network** (default)
   - Global coverage with `/states/all` endpoint
   - Historical flight tracks support
   - Optional OAuth2 authentication (see Secrets.swift)
   - Rate limit: 60 seconds (anonymous) or lower with auth
   - Docs: https://openskynetwork.github.io/opensky-api/

2. **adsb.lol**
   - Geographic queries only (250 NM radius)
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://api.adsb.lol/docs

3. **adsb.fi**
   - Geographic queries only (250 NM radius)
   - Personal use only license
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://github.com/adsbfi/opendata

4. **Airplanes.live**
   - Geographic queries only (250 NM radius)
   - Community-driven
   - No authentication required
   - Rate limit: 1 request/second
   - Docs: https://airplanes.live/api-guide/

### Changing API Provider

Edit `Config.swift` and change:
```swift
static var provider: ADSBProvider = .opensky  // Change to .adsbLol, .adsbFi, or .airplanesLive
```

For non-global APIs, configure the geographic center:
```swift
static var defaultLatitude: Double = 39.8283   // Your region's center
static var defaultLongitude: Double = -98.5795
static var defaultRadius: Double = 250.0       // Nautical miles (max 250)
```

### OpenSky Authentication (Optional)

- Credentials stored in `Secrets.swift` (clientId and clientSecret)
- Token automatically fetched and refreshed by `FlightService.getValidToken()`
- If credentials are placeholder values or auth fails, falls back to anonymous access

## Data Flow

1. **Location Setup**: `FlightViewModel.setupLocationManager()` requests user location permission
2. **Initial Fetch**: `startFetching()` initiates first fetch with provider-specific rate limit timer
3. **API Call**: `FlightService.fetchFlights(lat:lon:radius:)` calls provider-specific endpoint:
   - Uses user location if available, otherwise current map view region, or falls back to config defaults
   - OpenSky: `/states/all` for global coverage (ignores location params)
   - Regional APIs: `/lat/{lat}/lon/{lon}/dist/{radius}` centered on user/viewport
4. **Response Parsing**: Based on provider format:
   - OpenSky: Array-based format (stateArray)
   - ADSBExchange v2: JSON objects with "ac" array (adsb.lol, adsb.fi, airplanes.live)
5. **Filtering**: Active flights only (altitude > 0, velocity > 0), limited to 500 max for performance
6. **Map Updates**: SwiftUI bindings update Map with annotations and flight path polyline
7. **Viewport Tracking**: `onChange(of: mapCameraPosition)` extracts region for potential re-fetch
8. **Selection**: In Select mode, tapping annotation triggers `fetchTrack(for:)` (OpenSky only)

## UI Interaction Patterns

### Control Modes (ContentView.swift:17-39)
The app has 4 control modes accessed via center button:

1. **Pan Mode**: Direction keys move map (1 degree per press)
2. **Zoom Mode**: Up/Down keys zoom in/out (1.5x factor)
3. **Select Mode**: Navigate and select flights with direction keys + center
4. **Search Mode**: Text field appears, type to filter flights

### Remote Controls
- **Center Button (Short Press)**: Cycle through control modes
- **Center Button (Long Press 0.5s)**: Toggle control mode UI on/off
- **Direction Keys**: Context-aware based on active mode
- **Play/Pause**: Toggle all UI visibility

### Location-Based Features
- **Initial View**: Centers on user location with 5-degree span
- **Viewport Updates**: Map tracks current region for potential optimized fetching
- **Radius**: 500 statute miles (~250 NM for API limit)
- **tvOS Limitation**: Apple TV doesn't have GPS, uses network-based approximate location or Config.swift defaults
- **Fallback**: Uses center of US (39.8283, -98.5795) if location unavailable
- **Manual Override**: Set `defaultLatitude`/`defaultLongitude` in Config.swift for your region
